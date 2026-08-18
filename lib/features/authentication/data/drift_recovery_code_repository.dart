import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';

final class DriftRecoveryCodeRepository implements RecoveryCodeRepository {
  DriftRecoveryCodeRepository(this._database);

  final MaestroDatabase _database;

  @override
  Future<void> saveAll(String userId, List<StoredRecoveryCode> codes) =>
      _database.transaction(() async {
        for (final code in codes) {
          await _database.into(_database.localRecoveryCodes).insert(
            LocalRecoveryCodesCompanion.insert(
              id: code.id,
              userId: userId,
              digest: code.digest,
              issuedAt: code.issuedAt,
            ),
          );
        }
      });

  @override
  Future<bool> consumeUnusedDigest(String digest, DateTime consumedAt) async {
    final updated = await (_database.update(_database.localRecoveryCodes)
          ..where(
            (row) => row.digest.equals(digest) & row.consumedAt.isNull(),
          ))
        .write(LocalRecoveryCodesCompanion(consumedAt: Value(consumedAt)));
    return updated == 1;
  }
}
