import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart'
    show MaestroDatabase;
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/data/drift_authentication_repository.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';

void main() {
  late MaestroDatabase database;
  late DriftAuthenticationRepository repository;

  setUp(() {
    database = MaestroDatabase(NativeDatabase.memory());
    repository = DriftAuthenticationRepository(database);
  });

  tearDown(() => database.close());

  test(
    'GivenCaseVariantEmail_WhenInserted_ThenUniqueConstraintRejectsIt',
    () async {
      await repository.save(_user(email: 'user@example.com'));

      await expectLater(
        repository.save(_user(id: 'user-2', email: 'USER@example.com')),
        throwsA(
          isA<SqliteException>().having(
            (error) => error.extendedResultCode,
            'extendedResultCode',
            2067,
          ),
        ),
      );
    },
  );

  test(
    'GivenSecondOperatingSystemUser_WhenInserted_ThenUniqueConstraintRejectsIt',
    () async {
      await repository.save(
        _user(
          id: 'os-user-1',
          email: null,
          authenticationMethod: AuthenticationMethod.operatingSystem,
          verifierKey: null,
        ),
      );

      await expectLater(
        repository.save(
          _user(
            id: 'os-user-2',
            email: null,
            authenticationMethod: AuthenticationMethod.operatingSystem,
            verifierKey: null,
          ),
        ),
        throwsA(
          isA<SqliteException>().having(
            (error) => error.extendedResultCode,
            'extendedResultCode',
            2067,
          ),
        ),
      );
    },
  );

  test('GivenStoredUser_WhenFoundByEmail_ThenAllMetadataIsRestored', () async {
    final expected = _user(email: ' USER@example.com ');
    await repository.save(expected);

    final actual = await repository.findByEmail(
      NormalizedEmail.parse('user@example.com'),
    );

    expect(actual?.id, 'user-1');
    expect(actual?.email?.value, 'user@example.com');
    expect(actual?.authenticationMethod, AuthenticationMethod.emailPassword);
    expect(actual?.verifierKey, 'maestro.auth.verifier.user-1');
    expect(actual?.createdAt, DateTime.utc(2026, 8, 5, 12));
    expect(actual?.lastAuthenticatedAt, DateTime.utc(2026, 8, 5, 13));
  });

  test(
    'GivenOperatingSystemAndEmailUsers_WhenFindingOperatingSystemUser_ThenOnlyOperatingSystemUserIsReturned',
    () async {
      await repository.save(_user());
      await repository.save(
        _user(
          id: 'os-user',
          email: null,
          authenticationMethod: AuthenticationMethod.operatingSystem,
          verifierKey: null,
        ),
      );

      final actual = await repository.findOperatingSystemUser();

      expect(actual?.id, 'os-user');
      expect(actual?.email, isNull);
      expect(
        actual?.authenticationMethod,
        AuthenticationMethod.operatingSystem,
      );
      expect(actual?.verifierKey, isNull);
    },
  );

  test(
    'GivenStoredUser_WhenAuthenticationTimeUpdatedAndUserDeleted_ThenMutationsTargetThatUser',
    () async {
      await repository.save(_user());
      await repository.save(_user(id: 'user-2', email: 'second@example.com'));

      await repository.updateLastAuthenticatedAt(
        'user-2',
        DateTime.utc(2026, 8, 5, 14),
      );
      await repository.delete('user-1');

      expect(
        await repository.findByEmail(NormalizedEmail.parse('user@example.com')),
        isNull,
      );
      final retained = await repository.findByEmail(
        NormalizedEmail.parse('second@example.com'),
      );
      expect(retained?.lastAuthenticatedAt, DateTime.utc(2026, 8, 5, 14));
    },
  );

  test(
    'GivenAuditEvents_WhenAppended_ThenRedactedFieldsRemainSortableByTimestamp',
    () async {
      await repository.append(
        _audit(
          id: 'audit-2',
          occurredAt: DateTime.utc(2026, 8, 5, 15),
          action: AuthenticationAuditAction.signIn,
          outcome: AuthenticationAuditOutcome.success,
          details: '{"principal":"known"}',
        ),
      );
      await repository.append(
        _audit(
          id: 'audit-1',
          occurredAt: DateTime.utc(2026, 8, 5, 14),
          action: AuthenticationAuditAction.signInFailed,
          outcome: AuthenticationAuditOutcome.failure,
          details: '{"principal":"unknown"}',
        ),
      );

      final rows = await database
          .customSelect(
            'SELECT id, actor_id, action, target, outcome, occurred_at, details '
            'FROM audit_events ORDER BY occurred_at, id',
          )
          .get();

      expect(
        rows
            .map(
              (row) => <Object?>[
                row.read<String>('id'),
                row.read<String>('actor_id'),
                row.read<String>('action'),
                row.read<String>('target'),
                row.read<String>('outcome'),
                DateTime.fromMillisecondsSinceEpoch(
                  row.read<int>('occurred_at') * 1000,
                  isUtc: true,
                ),
                row.read<String>('details'),
              ],
            )
            .toList(),
        <List<Object?>>[
          <Object?>[
            'audit-1',
            'actor-1',
            'signInFailed',
            'unknown',
            'failure',
            DateTime.utc(2026, 8, 5, 14),
            '{"principal":"unknown"}',
          ],
          <Object?>[
            'audit-2',
            'actor-1',
            'signIn',
            'unknown',
            'success',
            DateTime.utc(2026, 8, 5, 15),
            '{"principal":"known"}',
          ],
        ],
      );
    },
  );

  test(
    'GivenTwoAuditEvents_WhenOneIsDeleted_ThenOnlyThatEventIsRemoved',
    () async {
      await repository.append(
        _audit(
          id: 'audit-1',
          occurredAt: DateTime.utc(2026, 8, 5, 14),
          action: AuthenticationAuditAction.accountCreated,
          outcome: AuthenticationAuditOutcome.success,
          details: '{"principal":"known"}',
        ),
      );
      await repository.append(
        _audit(
          id: 'audit-2',
          occurredAt: DateTime.utc(2026, 8, 5, 15),
          action: AuthenticationAuditAction.signIn,
          outcome: AuthenticationAuditOutcome.success,
          details: '{"principal":"known"}',
        ),
      );

      await repository.deleteEvent('audit-1');

      final rows = await database
          .customSelect('SELECT id FROM audit_events ORDER BY id')
          .get();
      expect(rows.map((row) => row.read<String>('id')).toList(), <String>[
        'audit-2',
      ]);
    },
  );
}

LocalUser _user({
  String id = 'user-1',
  String? email = 'user@example.com',
  AuthenticationMethod authenticationMethod =
      AuthenticationMethod.emailPassword,
  String? verifierKey = 'maestro.auth.verifier.user-1',
}) {
  return LocalUser(
    id: id,
    email: email == null ? null : NormalizedEmail.parse(email),
    authenticationMethod: authenticationMethod,
    verifierKey: verifierKey,
    createdAt: DateTime.utc(2026, 8, 5, 12),
    lastAuthenticatedAt: DateTime.utc(2026, 8, 5, 13),
  );
}

AuthenticationAuditEvent _audit({
  required String id,
  required DateTime occurredAt,
  required AuthenticationAuditAction action,
  required AuthenticationAuditOutcome outcome,
  required String details,
}) {
  return AuthenticationAuditEvent(
    id: id,
    actorId: 'actor-1',
    action: action,
    target: 'unknown',
    outcome: outcome,
    occurredAt: occurredAt,
    details: details,
  );
}
