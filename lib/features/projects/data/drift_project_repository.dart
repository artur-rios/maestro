import 'package:drift/drift.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/database/maestro_database.dart' as db;
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:sqlite3/sqlite3.dart';

final class DriftProjectRepository implements ProjectRepository {
  const DriftProjectRepository(this._database);

  final db.MaestroDatabase _database;

  @override
  Future<List<ProjectRecord>> listRetained() async {
    final query = _database.select(_database.projects)
      ..orderBy(<OrderingTerm Function(db.Projects)>[
        (table) => OrderingTerm.asc(table.normalizedName),
        (table) => OrderingTerm.asc(table.name),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<ProjectRecord?> findById(String id) async {
    final row = await (_database.select(
      _database.projects,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<ProjectRecord?> findByNormalizedName(String normalizedName) async {
    final row =
        await (_database.select(_database.projects)
              ..where((table) => table.normalizedName.equals(normalizedName)))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<Result<void>> save(ProjectRecord record) async {
    try {
      await _database
          .into(_database.projects)
          .insert(
            db.ProjectsCompanion.insert(
              id: record.id,
              name: record.name,
              normalizedName: record.normalizedName,
              folderPath: record.folderPath,
              createdAt: record.createdAt.toUtc(),
              updatedAt: record.updatedAt.toUtc(),
              deletedAt: Value<DateTime?>(record.deletedAt?.toUtc()),
            ),
          );
      return const Success<void>(null);
    } on SqliteException catch (error) {
      if (error.extendedResultCode == 2067 &&
          error.message.contains('projects.normalized_name')) {
        return const FailureResult<void>(
          StorageFailure(
            code: ProjectRepositoryFailureCodes.duplicateName,
            message: 'A retained project already uses this name.',
          ),
        );
      }
      rethrow;
    }
  }

  static ProjectRecord _toDomain(db.Project row) {
    return ProjectRecord(
      id: row.id,
      name: row.name,
      normalizedName: row.normalizedName,
      folderPath: row.folderPath,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      deletedAt: row.deletedAt?.toUtc(),
    );
  }
}
