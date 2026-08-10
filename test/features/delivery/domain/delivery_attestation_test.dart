import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/delivery/domain/delivery_attestation.dart';

void main() {
  test(
    'GivenExactTestAndReviewAttestations_WhenReadingDeliveryEvidence_ThenItBuildsTypedEvidence',
    () {
      final test = DeliveryTestAttestation.parse(
        '{"schema":1,"kind":"test","headCommit":"abc123","passedAt":"2026-08-10T12:00:00Z"}',
      );
      final review = DeliveryReviewAttestation.parse(
        '{"schema":1,"kind":"review","outcome":"approved","summary":"Independent review passed."}',
      );

      expect(test, isA<DeliveryTestAttestationValid>());
      expect(review, isA<DeliveryReviewAttestationApproved>());
      expect((test as DeliveryTestAttestationValid).headCommit, 'abc123');
      expect(
        (review as DeliveryReviewAttestationApproved).summary,
        'Independent review passed.',
      );
    },
  );

  test(
    'GivenMissingOrInvalidAttestations_WhenReadingDeliveryEvidence_ThenTheyFailSafely',
    () {
      expect(
        DeliveryTestAttestation.parse('{"headCommit":"abc123"}'),
        isA<DeliveryTestAttestationInvalid>(),
      );
      expect(
        DeliveryReviewAttestation.parse(
          '{"schema":1,"kind":"review","outcome":"approved","summary":"ok","extra":true}',
        ),
        isA<DeliveryReviewAttestationInvalid>(),
      );
    },
  );
}
