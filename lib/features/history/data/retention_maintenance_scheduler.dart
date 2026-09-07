// Public constructor parameter names document injected ports.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:maestro/core/logging/diagnostic_log.dart';
import 'package:maestro/features/history/data/retention_service.dart';

/// Applies the saved retention policy once for each session that signs in.
///
/// Retention used to run only where the history panel was opened, so an
/// installation whose user never opened that view compacted nothing and
/// enforced no storage ceiling however the policy was configured (UC-13). A
/// session start is the earliest moment an actor id exists to audit the pass
/// against, so it is where the policy is applied.
final class RetentionMaintenanceScheduler {
  RetentionMaintenanceScheduler({
    required RetentionService service,
    required Stream<String?> actors,
    DiagnosticLog diagnostics = const NoopDiagnosticLog(),
  }) : _service = service,
       _actors = actors,
       _diagnostics = diagnostics;

  final RetentionService _service;
  final Stream<String?> _actors;
  final DiagnosticLog _diagnostics;

  StreamSubscription<String?>? _subscription;
  String? _appliedFor;

  /// The pass in flight, exposed so a test can await what a session started.
  Future<void>? get pending => _pending;
  Future<void>? _pending;

  void start() {
    _subscription ??= _actors.listen(_onActor);
  }

  /// Detaches the listener. Synchronous by design.
  ///
  /// Cancelling a broadcast subscription removes it from the controller's
  /// listener list there and then; the future it returns carries no cleanup
  /// worth waiting for. Awaiting it during shutdown, while the service that
  /// owns the stream is being torn down in the same pass, is how a composition
  /// deadlocks on its own teardown.
  void stop() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _onActor(String? actorId) {
    if (actorId == null || actorId.trim().isEmpty) {
      // Signing out ends the session this pass was attributed to, so the next
      // sign-in gets its own.
      _appliedFor = null;
      return;
    }
    if (_appliedFor == actorId) return;
    _appliedFor = actorId;
    _pending = _apply(actorId);
  }

  Future<void> _apply(String actorId) async {
    try {
      final result = await _service.applyPolicy(actorId: actorId);
      await _diagnostics.record('retention: ${result.summary}');
    } on Object catch (error) {
      // A maintenance pass that cannot run is recorded and dropped: it must
      // never take down the session that triggered it.
      await _diagnostics.record('retention: the pass did not finish — $error');
    }
  }
}
