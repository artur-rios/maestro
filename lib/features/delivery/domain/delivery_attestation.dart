import 'dart:convert';

import 'package:maestro/features/runs/domain/run_models.dart';

/// Trusted, durable evidence emitted by a successful Test step.
///
/// This deliberately accepts an exact, small schema: autonomous delivery must
/// never infer privileged state from an arbitrary agent context string.
sealed class DeliveryTestAttestation {
  const DeliveryTestAttestation();

  static DeliveryTestAttestation parse(String source) {
    final value = _exactObject(source, const <String>{
      'schema',
      'kind',
      'headCommit',
      'passedAt',
    });
    if (value == null ||
        value['schema'] != 1 ||
        value['kind'] != 'test' ||
        !_nonBlank(value['headCommit']) ||
        value['passedAt'] is! String) {
      return const DeliveryTestAttestationInvalid();
    }
    final passedAt = DateTime.tryParse(value['passedAt']! as String);
    if (passedAt == null) return const DeliveryTestAttestationInvalid();
    return DeliveryTestAttestationValid(
      headCommit: value['headCommit']! as String,
      passedAt: passedAt.toUtc(),
    );
  }
}

final class DeliveryTestAttestationValid extends DeliveryTestAttestation {
  const DeliveryTestAttestationValid({
    required this.headCommit,
    required this.passedAt,
  });

  final String headCommit;
  final DateTime passedAt;
}

final class DeliveryTestAttestationInvalid extends DeliveryTestAttestation {
  const DeliveryTestAttestationInvalid();
}

/// Trusted, durable evidence emitted by a distinct Review step.
sealed class DeliveryReviewAttestation {
  const DeliveryReviewAttestation();

  static DeliveryReviewAttestation parse(String source) {
    final value = _exactObject(source, const <String>{
      'schema',
      'kind',
      'outcome',
      'summary',
    });
    if (value == null ||
        value['schema'] != 1 ||
        value['kind'] != 'review' ||
        !_nonBlank(value['summary'])) {
      return const DeliveryReviewAttestationInvalid();
    }
    return switch (value['outcome']) {
      'approved' => DeliveryReviewAttestationApproved(
        summary: value['summary']! as String,
      ),
      'requestedChanges' => DeliveryReviewAttestationRequestedChanges(
        summary: value['summary']! as String,
      ),
      _ => const DeliveryReviewAttestationInvalid(),
    };
  }
}

final class DeliveryReviewAttestationApproved
    extends DeliveryReviewAttestation {
  const DeliveryReviewAttestationApproved({required this.summary});
  final String summary;
}

final class DeliveryReviewAttestationRequestedChanges
    extends DeliveryReviewAttestation {
  const DeliveryReviewAttestationRequestedChanges({required this.summary});
  final String summary;
}

final class DeliveryReviewAttestationInvalid extends DeliveryReviewAttestation {
  const DeliveryReviewAttestationInvalid();
}

Map<String, Object?>? _exactObject(String source, Set<String> expectedKeys) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?> ||
        decoded.length != expectedKeys.length ||
        !decoded.keys.toSet().containsAll(expectedKeys)) {
      return null;
    }
    return decoded;
  } on FormatException {
    return null;
  }
}

bool _nonBlank(Object? value) => value is String && value.trim().isNotEmpty;

/// Extracts the three attestations required for autonomous delivery from the
/// immutable snapshot and its durable successful attempts.
final class DeliveryAttestationSet {
  const DeliveryAttestationSet._({
    required this.executeModel,
    required this.reviewerIdentity,
    required this.test,
    required this.review,
  });

  final String executeModel;
  final String reviewerIdentity;
  final DeliveryTestAttestationValid test;
  final DeliveryReviewAttestationApproved review;

  static DeliveryAttestationSet? fromSnapshot(
    RunSnapshot snapshot,
    Iterable<RunAttempt> attempts,
  ) {
    RunSnapshotStep? execute;
    RunSnapshotStep? test;
    RunSnapshotStep? review;
    for (final step in snapshot.steps) {
      switch (step.kind) {
        case 'execute':
          execute ??= step;
        case 'test':
          test ??= step;
        case 'review':
          review ??= step;
      }
    }
    if (execute == null ||
        test == null ||
        review == null ||
        !(execute.position < test.position &&
            test.position < review.position)) {
      return null;
    }
    final executeModel = execute?.model;
    final reviewerIdentity = review?.model;
    if (!_nonBlank(executeModel) || !_nonBlank(reviewerIdentity)) return null;
    final executing = executeModel!;
    final reviewer = reviewerIdentity!;
    if (executing == reviewer) return null;
    final testContext = _latestContext(attempts, test?.id);
    final reviewContext = _latestContext(attempts, review?.id);
    if (testContext == null || reviewContext == null) return null;
    final testEvidence = DeliveryTestAttestation.parse(testContext.value);
    final reviewEvidence = DeliveryReviewAttestation.parse(reviewContext.value);
    if (testEvidence is! DeliveryTestAttestationValid ||
        reviewEvidence is! DeliveryReviewAttestationApproved) {
      return null;
    }
    return DeliveryAttestationSet._(
      executeModel: executing,
      reviewerIdentity: reviewer,
      test: testEvidence,
      review: reviewEvidence,
    );
  }
}

DeclaredContext? _latestContext(Iterable<RunAttempt> attempts, String? stepId) {
  if (stepId == null) return null;
  RunAttempt? latest;
  for (final attempt in attempts) {
    if (attempt.snapshotStepId != stepId ||
        attempt.status != AttemptStatus.succeeded ||
        attempt.declaredContext == null ||
        (latest != null && latest.attemptNumber >= attempt.attemptNumber)) {
      continue;
    }
    latest = attempt;
  }
  return latest?.declaredContext;
}
