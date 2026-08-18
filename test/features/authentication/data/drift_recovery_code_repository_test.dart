import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/data/drift_recovery_code_repository.dart';

void main() {
  const userId = 'local-user';
  final issuedAt = DateTime.utc(2026, 8, 18, 12);
  final code = StoredRecoveryCode(
    id: 'recovery-code',
    digest: 'a' * 64,
    issuedAt: issuedAt,
  );

  Future<MaestroDatabase> createDatabase() async {
    final database = MaestroDatabase(NativeDatabase.memory());
    await database
        .into(database.localUsers)
        .insert(
          LocalUsersCompanion.insert(
            id: userId,
            authMethod: 'password',
            createdAt: issuedAt,
          ),
        );
    return database;
  }

  Future<void> insertUser(MaestroDatabase database, String id, String email) {
    return database
        .into(database.localUsers)
        .insert(
          LocalUsersCompanion.insert(
            id: id,
            email: Value(email),
            authMethod: 'password',
            verifierKey: Value('verifier-$id'),
            createdAt: issuedAt,
          ),
        );
  }

  test('GivenUnusedDigest_WhenConsumed_ThenItIsConsumedOnce', () async {
    final database = await createDatabase();
    addTearDown(database.close);
    final codes = DriftRecoveryCodeRepository(database);
    final consumedAt = issuedAt.add(const Duration(hours: 1));

    await codes.saveAll(userId, <StoredRecoveryCode>[code]);

    expect(
      await codes.consumeUnusedDigest(userId, code.digest, consumedAt),
      isTrue,
    );
    expect(
      await codes.consumeUnusedDigest(
        userId,
        code.digest,
        consumedAt.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      (await database.select(database.localRecoveryCodes).getSingle())
          .consumedAt
          ?.toUtc(),
      consumedAt,
    );
  });

  test(
    'GivenDigestOwnedByAnotherUser_WhenConsumed_ThenOwnerAndDigestMustBothMatchAtomically',
    () async {
      final database = await createDatabase();
      addTearDown(database.close);
      const otherUserId = 'other-local-user';
      await insertUser(database, otherUserId, 'other@example.com');
      final codes = DriftRecoveryCodeRepository(database);
      final consumedAt = issuedAt.add(const Duration(hours: 1));
      await codes.saveAll(userId, <StoredRecoveryCode>[code]);

      expect(
        await codes.consumeUnusedDigest(otherUserId, code.digest, consumedAt),
        isFalse,
      );
      expect(
        (await database.select(database.localRecoveryCodes).getSingle())
            .consumedAt,
        isNull,
      );
      expect(
        await codes.consumeUnusedDigest(userId, code.digest, consumedAt),
        isTrue,
      );
    },
  );

  test('GivenDuplicateDigestSet_WhenSaved_ThenTransactionRollsBack', () async {
    final database = await createDatabase();
    addTearDown(database.close);
    final codes = DriftRecoveryCodeRepository(database);

    await expectLater(
      codes.saveAll(userId, <StoredRecoveryCode>[
        code,
        StoredRecoveryCode(
          id: 'duplicate-digest',
          digest: code.digest,
          issuedAt: issuedAt,
        ),
      ]),
      throwsA(isA<Object>()),
    );

    expect(await database.select(database.localRecoveryCodes).get(), isEmpty);
  });
}
