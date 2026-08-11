// Injected field names retain their explicit public dependency labels.
// ignore_for_file: prefer_initializing_formals

import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/updates/presentation/update_controller.dart';

final class DriftUpdateAuditRecorder implements UpdateAuditRecorder {
  const DriftUpdateAuditRecorder({
    required MaestroDatabase database,
    required String actorId,
    required DateTime Function() clock,
    required String Function() newId,
  }) : _database = database,
       _actorId = actorId,
       _clock = clock,
       _newId = newId;
  final MaestroDatabase _database;
  final String _actorId;
  final DateTime Function() _clock;
  final String Function() _newId;
  @override
  Future<void> record({
    required String action,
    required String outcome,
    required String details,
  }) => _database
      .into(_database.auditEvents)
      .insert(
        AuditEventsCompanion.insert(
          id: _newId(),
          actorId: _actorId,
          action: action,
          target: 'application.update',
          outcome: outcome,
          occurredAt: _clock().toUtc(),
          details: details,
        ),
      );
}
