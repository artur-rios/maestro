// Public constructor parameter names document injected update boundaries.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/update_approval.dart';
import 'package:maestro/platform/updates/update_service.dart';

final class UpdateState {
  const UpdateState({
    this.checking = false,
    this.installing = false,
    this.candidate,
    this.message,
  });
  final bool checking;
  final bool installing;
  final UpdateCandidate? candidate;
  final String? message;
}

abstract interface class UpdateAuditRecorder {
  Future<void> record({
    required String action,
    required String outcome,
    required String details,
  });
}

final class UpdateController extends ChangeNotifier {
  UpdateController({UpdateService? service, UpdateAuditRecorder? audits})
    : _service = service,
      _audits = audits;
  final UpdateService? _service;
  final UpdateAuditRecorder? _audits;
  UpdateState state = const UpdateState();

  Future<void> check() async {
    final service = _service;
    if (service == null) {
      state = const UpdateState(
        message:
            'Updates are unavailable in this build. Configure a release public key and immutable manifest URLs.',
      );
      notifyListeners();
      await _audit('update.check', 'unavailable', 'configuration');
      return;
    }
    state = UpdateState(checking: true, candidate: state.candidate);
    notifyListeners();
    final result = await service.check(UpdateCheckReason.manual);
    state = switch (result) {
      Success<UpdateCandidate?>(:final value) when value != null => UpdateState(
        candidate: value,
      ),
      Success<UpdateCandidate?>() => const UpdateState(
        message: 'Maestro is already up to date.',
      ),
      FailureResult<UpdateCandidate?>(:final failure) => UpdateState(
        message: '${failure.message} Try again later.',
      ),
    };
    notifyListeners();
    await _audit(
      'update.check',
      result is Success<UpdateCandidate?> ? 'success' : 'failed',
      state.candidate?.artifact.sha256 ?? state.message ?? 'no-update',
    );
  }

  Future<void> install({required bool approved}) async {
    final candidate = state.candidate;
    if (candidate == null) return;
    if (!approved) {
      state = UpdateState(
        candidate: candidate,
        message: 'Update declined. The current installation is unchanged.',
      );
      notifyListeners();
      await _audit('update.install', 'declined', candidate.artifact.sha256);
      return;
    }
    state = UpdateState(installing: true, candidate: candidate);
    notifyListeners();
    final service = _service;
    if (service == null) return;
    final result = await service.install(
      candidate,
      UpdateApproval.approved(candidate.artifact.sha256),
    );
    state = switch (result) {
      Success<UpdateOutcome>(:final value) => UpdateState(
        message:
            'Update ${value.version} was staged for ${value.packageType} installation.',
      ),
      FailureResult<UpdateOutcome>(:final failure) => UpdateState(
        candidate: candidate,
        message:
            '${failure.message} The current installation and user data were preserved.',
      ),
    };
    notifyListeners();
    await _audit(
      'update.install',
      result is Success<UpdateOutcome> ? 'success' : 'failed',
      candidate.artifact.sha256,
    );
  }

  Future<void> _audit(String action, String outcome, String details) async {
    try {
      await _audits?.record(action: action, outcome: outcome, details: details);
    } on Object {
      // Auditing cannot reverse an already completed package operation.
    }
  }
}
