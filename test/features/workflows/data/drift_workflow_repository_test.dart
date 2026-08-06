import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart'
    hide WorkflowStep;
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/data/drift_workflow_repository.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  late MaestroDatabase database;
  late DriftWorkflowRepository repository;

  setUp(() {
    database = MaestroDatabase(NativeDatabase.memory());
    repository = DriftWorkflowRepository(database);
  });

  tearDown(() => database.close());

  test(
    'GivenAggregate_WhenInsertedAndLoaded_ThenRoundTripIsDeterministic',
    () async {
      await _insertProject(database, 'project-b');
      await _insertProject(database, 'project-a');
      final definition = _definition(
        projectIds: const ['project-b', 'project-a'],
      );

      final result = await repository.save(
        definition: definition,
        expectedRevision: null,
      );

      expect(result, isA<WorkflowRepositorySaved>());
      expect(
        await repository.findById('workflow-1'),
        _matchesDefinition(
          definition,
          projectIds: const ['project-a', 'project-b'],
        ),
      );
      expect(
        (await repository.list()).single,
        _matchesDefinition(
          definition,
          projectIds: const ['project-a', 'project-b'],
        ),
      );
      final stored = await database
          .customSelect(
            'SELECT configuration, cli, model FROM workflow_steps ORDER BY position',
          )
          .get();
      expect(stored.map((row) => row.read<String>('configuration')), [
        '{}',
        '{}',
      ]);
      expect(
        stored.every(
          (row) => row.data['cli'] == null && row.data['model'] == null,
        ),
        isTrue,
      );
      final metadata = await database
          .customSelect('SELECT name, unit_type FROM workflows')
          .getSingle();
      expect(metadata.data.values.join(' '), isNot(contains('private')));
      expect(
        stored.expand((row) => row.data.values).join(' '),
        isNot(contains('private')),
      );
    },
  );

  test(
    'GivenEqualClockEdits_WhenRevisionChanges_ThenStaleThirdEditIsRejectedUnchanged',
    () async {
      final created = _definition();
      await repository.save(definition: created, expectedRevision: null);
      final first = _definition(
        revision: 2,
        name: 'First',
        updatedAt: created.updatedAt,
      );
      final second = _definition(
        revision: 3,
        name: 'Second',
        updatedAt: created.updatedAt,
      );
      final stale = _definition(
        revision: 3,
        name: 'Stale',
        updatedAt: created.updatedAt,
      );

      expect(
        await repository.save(definition: first, expectedRevision: 1),
        isA<WorkflowRepositorySaved>(),
      );
      expect(
        await repository.save(definition: second, expectedRevision: 2),
        isA<WorkflowRepositorySaved>(),
      );
      expect(
        await repository.save(definition: stale, expectedRevision: 2),
        isA<WorkflowRepositoryRevisionConflict>(),
      );

      final actual = await repository.findById(created.id);
      expect(actual, _matchesDefinition(second));
      expect(actual!.steps.map((step) => step.id), [
        'step-plan',
        'step-execute',
      ]);
    },
  );

  test(
    'GivenInvalidReplacement_WhenEdited_ThenWholeAggregateRollsBack',
    () async {
      final created = _definition();
      await repository.save(definition: created, expectedRevision: null);
      await database.customStatement('''
      CREATE TRIGGER reject_second_step BEFORE INSERT ON workflow_steps
      WHEN NEW.name = 'Rejected' BEGIN SELECT RAISE(ABORT, 'injected'); END
    ''');
      final invalid = _definition(
        revision: 2,
        name: 'Changed',
        steps: [
          _step('step-plan', 0, WorkflowStepKind.plan, 'Plan'),
          _step('step-execute', 1, WorkflowStepKind.execute, 'Rejected'),
        ],
      );

      await expectLater(
        repository.save(definition: invalid, expectedRevision: 1),
        throwsA(anything),
      );

      expect(
        await repository.findById(created.id),
        _matchesDefinition(created),
      );
    },
  );

  test(
    'GivenMissingAssociation_WhenInserted_ThenWholeAggregateRollsBack',
    () async {
      final invalid = _definition(projectIds: const ['missing-project']);

      await expectLater(
        repository.save(definition: invalid, expectedRevision: null),
        throwsA(anything),
      );

      expect(
        await database.customSelect('SELECT * FROM workflows').get(),
        isEmpty,
      );
      expect(
        await database.customSelect('SELECT * FROM workflow_steps').get(),
        isEmpty,
      );
      expect(
        await database
            .customSelect('SELECT * FROM workflow_project_refs')
            .get(),
        isEmpty,
      );
    },
  );

  test(
    'GivenNonContiguousPositions_WhenSaved_ThenAggregateIsRejectedWithoutRows',
    () async {
      final invalid = _definition(
        steps: [
          _step('step-plan', 0, WorkflowStepKind.plan, 'Plan'),
          _step('step-execute', 2, WorkflowStepKind.execute, 'Execute'),
        ],
      );

      await expectLater(
        repository.save(definition: invalid, expectedRevision: null),
        throwsStateError,
      );
      expect(
        await database.customSelect('SELECT * FROM workflows').get(),
        isEmpty,
      );
    },
  );

  test('GivenAssignmentPair_WhenStored_ThenBothOrNeitherAreAtomic', () async {
    final futureAssigned = _definition(
      steps: [
        _step(
          'step-plan',
          0,
          WorkflowStepKind.plan,
          'Plan',
          cli: 'codex',
          model: 'gpt',
        ),
        _step('step-execute', 1, WorkflowStepKind.execute, 'Execute'),
      ],
    );
    await repository.save(definition: futureAssigned, expectedRevision: null);
    expect(
      (await repository.findById(futureAssigned.id))!.steps.first.cli,
      'codex',
    );

    await expectLater(
      database.customStatement(
        'UPDATE workflow_steps SET model = NULL WHERE id = ?',
        ['step-plan'],
      ),
      throwsA(anything),
    );
    expect(
      (await repository.findById(futureAssigned.id))!.steps.first.model,
      'gpt',
    );
  });

  test(
    'GivenOneOffWithAssociations_WhenSaved_ThenRejectedWithoutRows',
    () async {
      final invalid = _definition(
        kind: WorkflowKind.oneOff,
        name: null,
        projectIds: const ['project-a'],
      );
      await expectLater(
        repository.save(definition: invalid, expectedRevision: null),
        throwsStateError,
      );
      expect(
        await database.customSelect('SELECT * FROM workflows').get(),
        isEmpty,
      );
    },
  );

  test(
    'GivenReusableAssociations_WhenEitherOwnerDeleted_ThenOnlyLinksCascade',
    () async {
      await _insertProject(database, 'project-a');
      await _insertProject(database, 'unrelated');
      final definition = _definition(projectIds: const ['project-a']);
      await repository.save(definition: definition, expectedRevision: null);

      await database.customStatement(
        "DELETE FROM projects WHERE id = 'project-a'",
      );
      expect((await repository.findById(definition.id))!.projectIds, isEmpty);
      expect(
        await database
            .customSelect("SELECT id FROM projects WHERE id = 'unrelated'")
            .get(),
        hasLength(1),
      );

      await database.customStatement(
        "DELETE FROM workflows WHERE id = 'workflow-1'",
      );
      expect(
        await database.customSelect('SELECT * FROM workflow_steps').get(),
        isEmpty,
      );
      expect(
        await database
            .customSelect('SELECT * FROM workflow_project_refs')
            .get(),
        isEmpty,
      );
      expect(
        await database
            .customSelect("SELECT id FROM projects WHERE id = 'unrelated'")
            .get(),
        hasLength(1),
      );
    },
  );
}

WorkflowDefinition _definition({
  int revision = 1,
  String? name = 'Release',
  WorkflowKind kind = WorkflowKind.reusable,
  DateTime? updatedAt,
  List<WorkflowStep>? steps,
  List<String> projectIds = const [],
}) => WorkflowDefinition(
  id: 'workflow-1',
  revision: revision,
  kind: kind,
  name: name,
  unitType: WorkItemType.githubIssue,
  supervisedDelivery: true,
  createdAt: DateTime.utc(2026, 8, 6, 10),
  updatedAt: updatedAt ?? DateTime.utc(2026, 8, 6, 11),
  steps:
      steps ??
      [
        _step('step-plan', 0, WorkflowStepKind.plan, 'Plan'),
        _step('step-execute', 1, WorkflowStepKind.execute, 'Execute'),
      ],
  projectIds: projectIds,
);

WorkflowStep _step(
  String id,
  int position,
  WorkflowStepKind kind,
  String name, {
  String? cli,
  String? model,
}) => WorkflowStep(
  id: id,
  position: position,
  kind: kind,
  name: name,
  cli: cli,
  model: model,
);

Future<void> _insertProject(
  MaestroDatabase database,
  String id,
) => database.customStatement(
  'INSERT INTO projects (id, name, normalized_name, folder_path, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
  [id, id, id, r'C:\private\source', 1786000000, 1786000000],
);

Matcher _matchesDefinition(
  WorkflowDefinition expected, {
  List<String>? projectIds,
}) => isA<WorkflowDefinition>()
    .having((value) => value.id, 'id', expected.id)
    .having((value) => value.revision, 'revision', expected.revision)
    .having((value) => value.kind, 'kind', expected.kind)
    .having((value) => value.name, 'name', expected.name)
    .having((value) => value.unitType, 'unitType', expected.unitType)
    .having(
      (value) => value.supervisedDelivery,
      'supervisedDelivery',
      expected.supervisedDelivery,
    )
    .having((value) => value.createdAt, 'createdAt', expected.createdAt)
    .having((value) => value.updatedAt, 'updatedAt', expected.updatedAt)
    .having(
      (value) => value.steps
          .map(
            (step) => [
              step.id,
              step.position,
              step.kind,
              step.name,
              step.cli,
              step.model,
              step.configuration,
            ],
          )
          .toList(),
      'steps',
      expected.steps
          .map(
            (step) => [
              step.id,
              step.position,
              step.kind,
              step.name,
              step.cli,
              step.model,
              step.configuration,
            ],
          )
          .toList(),
    )
    .having(
      (value) => value.projectIds,
      'projectIds',
      projectIds ?? expected.projectIds,
    );
