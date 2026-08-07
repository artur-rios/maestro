import 'package:maestro/core/security/platform_protected_storage.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/core/storage/owned_path_policy.dart';
import 'package:maestro/features/foundation/application/foundation_probe.dart';
import 'package:maestro/features/foundation/application/reconcile_resources.dart';
import 'package:maestro/features/foundation/data/drift_owned_resource_store.dart';
import 'package:maestro/features/foundation/data/local_owned_resource_cleaner.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/runs/application/run_interruption_reconciler.dart';
import 'package:maestro/features/runs/data/drift_run_repository.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/common/executable_probe.dart';

final class ProductionFoundation {
  ProductionFoundation({
    required this.paths,
    required this.database,
    this.commandRunner = const ProcessCommandRunner(),
    DriftRunRepository? runRepository,
    DateTime Function()? clock,
    String Function()? newId,
  }) : runRepository = runRepository ?? DriftRunRepository(database),
       _clock = clock ?? _utcNow,
       _newId = newId ?? _fallbackId;

  final ApplicationPaths paths;
  final MaestroDatabase database;
  final CommandRunner commandRunner;
  final DriftRunRepository runRepository;
  final DateTime Function() _clock;
  final String Function() _newId;
  List<RunRecoveryOffer> recoveryOffers = const <RunRecoveryOffer>[];

  Future<List<RunRecoveryOffer>> recoverInterruptedRuns() async {
    recoveryOffers = await RunInterruptionReconciler(
      repository: runRepository,
      now: _clock,
      newId: _newId,
    ).reconcile();
    return recoveryOffers;
  }

  Future<void> selectRecovery(
    RunRecoveryOffer offer,
    RecoveryAction action,
  ) async {
    await RunInterruptionReconciler(
      repository: runRepository,
      now: _clock,
      newId: _newId,
    ).select(offer, action);
    recoveryOffers = recoveryOffers
        .where((value) => value.runId != offer.runId)
        .toList(growable: false);
  }

  List<FoundationProbe> get probes => <FoundationProbe>[
    _CallbackFoundationProbe('paths', true, _initializePaths),
    _CallbackFoundationProbe('logging', true, _initializeLogging),
    _CallbackFoundationProbe('settings', true, _initializeSettings),
    _CallbackFoundationProbe('protected-storage', true, _probeProtectedStorage),
    _CallbackFoundationProbe('database', true, _openDatabase),
    for (final specification in const <({String id, String command})>[
      (id: 'git', command: 'git'),
      (id: 'github', command: 'gh'),
      (id: 'claude-code', command: 'claude'),
      (id: 'codex', command: 'codex'),
      (id: 'opencode', command: 'opencode'),
    ])
      _CapabilityFoundationProbe(
        ExecutableProbe(
          commandRunner,
          id: specification.id,
          command: specification.command,
        ),
      ),
    _CallbackFoundationProbe('reconciliation', false, _reconcile),
  ];

  Future<String> _initializePaths() async {
    await paths.root.create(recursive: true);
    await paths.updatesDirectory.create(recursive: true);
    await paths.worktreesDirectory.create(recursive: true);
    return 'Application data paths are ready.';
  }

  Future<String> _initializeLogging() async {
    await paths.logsDirectory.create(recursive: true);
    return 'Bounded diagnostic logging is ready.';
  }

  Future<String> _initializeSettings() async {
    return 'Default retention and size settings are available.';
  }

  Future<String> _probeProtectedStorage() async {
    const storage = PlatformProtectedStorage(FlutterSecureStringStore());
    await storage.read('maestro.foundation.probe');
    return 'Operating-system protected storage is available.';
  }

  Future<String> _openDatabase() async {
    final result = await database.integrityCheck();
    if (result != 'ok') {
      throw StateError('SQLite integrity check failed.');
    }
    return 'SQLite storage passed its integrity check.';
  }

  Future<String> _reconcile() async {
    final store = DriftOwnedResourceStore(database);
    final pending = await store.findPending();
    final policy = OwnedPathPolicy(
      appPaths: paths,
      sourcePaths: const <String>[],
      ownedPaths: pending
          .where((resource) => resource.kind != OwnedResourceKind.process)
          .map((resource) => resource.path),
    );
    late final ReconciliationReport report;
    recoveryOffers =
        await RunInterruptionReconciler(
          repository: runRepository,
          now: _clock,
          newId: _newId,
        ).reconcileBefore(() async {
          report = await ReconcileResources(
            store: store,
            runActivity: runRepository,
            cleaner: const LocalOwnedResourceCleaner(),
            evaluatePath: policy.evaluate,
          )();
        });
    if (report.failures.isNotEmpty) {
      throw StateError(
        '${report.failures.length} resource cleanup(s) need review.',
      );
    }
    return 'Owned-resource reconciliation completed.';
  }
}

final class StaticFoundationProbe implements FoundationProbe {
  const StaticFoundationProbe(this.check);

  final FoundationCheck check;

  @override
  String get id => check.id;

  @override
  Future<FoundationCheck> probe() async => check;
}

final class _CallbackFoundationProbe implements FoundationProbe {
  const _CallbackFoundationProbe(this.id, this.blocking, this._callback);

  @override
  final String id;
  final bool blocking;
  final Future<String> Function() _callback;

  @override
  Future<FoundationCheck> probe() async {
    try {
      return FoundationCheck(
        id: id,
        health: FoundationHealth.ready,
        message: await _callback(),
      );
    } on Object catch (error) {
      return FoundationCheck(
        id: id,
        health: blocking ? FoundationHealth.blocked : FoundationHealth.degraded,
        message: '$id initialization failed: $error',
        remediation: 'Review diagnostics, correct the problem, and retry.',
      );
    }
  }
}

final class _CapabilityFoundationProbe implements FoundationProbe {
  const _CapabilityFoundationProbe(this._probe);

  final CapabilityProbe _probe;

  @override
  String get id => 'platform-capability';

  @override
  Future<FoundationCheck> probe() async {
    final capability = await _probe.probe();
    return FoundationCheck(
      id: capability.id,
      health: capability.state == CapabilityState.available
          ? FoundationHealth.ready
          : FoundationHealth.degraded,
      message: capability.message,
      remediation: capability.remediation,
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

String _fallbackId() =>
    'foundation-${DateTime.now().toUtc().microsecondsSinceEpoch}';
