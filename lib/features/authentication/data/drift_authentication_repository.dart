import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart' as db;
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart'
    as auth;

final class DriftAuthenticationRepository
    implements LocalUserRepository, AuditRepository {
  const DriftAuthenticationRepository(this._database);

  final db.MaestroDatabase _database;

  @override
  Future<auth.LocalUser?> findByEmail(auth.NormalizedEmail email) async {
    final row = await (_database.select(
      _database.localUsers,
    )..where((table) => table.email.equals(email.value))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<auth.LocalUser?> findOperatingSystemUser() async {
    final row =
        await (_database.select(_database.localUsers)..where(
              (table) => table.authMethod.equals(
                auth.AuthenticationMethod.operatingSystem.name,
              ),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(auth.LocalUser user) async {
    await _database
        .into(_database.localUsers)
        .insert(
          db.LocalUsersCompanion.insert(
            id: user.id,
            email: Value<String?>(user.email?.value),
            authMethod: user.authenticationMethod.name,
            verifierKey: Value<String?>(user.verifierKey),
            createdAt: user.createdAt.toUtc(),
            lastAuthenticatedAt: Value<DateTime?>(
              user.lastAuthenticatedAt?.toUtc(),
            ),
          ),
        );
  }

  @override
  Future<void> delete(String userId) async {
    await (_database.delete(
      _database.localUsers,
    )..where((table) => table.id.equals(userId))).go();
  }

  @override
  Future<void> updateLastAuthenticatedAt(String userId, DateTime value) async {
    await (_database.update(
      _database.localUsers,
    )..where((table) => table.id.equals(userId))).write(
      db.LocalUsersCompanion(
        lastAuthenticatedAt: Value<DateTime?>(value.toUtc()),
      ),
    );
  }

  @override
  Future<void> append(AuthenticationAuditEvent event) async {
    await _database
        .into(_database.auditEvents)
        .insert(
          db.AuditEventsCompanion.insert(
            id: event.id,
            actorId: event.actorId,
            action: event.action.name,
            target: event.target,
            outcome: event.outcome.name,
            occurredAt: event.occurredAt.toUtc(),
            details: event.details,
          ),
        );
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await (_database.delete(
      _database.auditEvents,
    )..where((table) => table.id.equals(eventId))).go();
  }

  static auth.LocalUser _toDomain(db.LocalUser row) {
    return auth.LocalUser(
      id: row.id,
      email: row.email == null ? null : auth.NormalizedEmail.parse(row.email!),
      authenticationMethod: auth.AuthenticationMethod.values.byName(
        row.authMethod,
      ),
      verifierKey: row.verifierKey,
      createdAt: row.createdAt.toUtc(),
      lastAuthenticatedAt: row.lastAuthenticatedAt?.toUtc(),
    );
  }
}
