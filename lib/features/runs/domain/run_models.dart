import 'dart:convert';
import 'dart:typed_data';

enum DeliveryMode { supervised, autonomous }

enum BranchWorkType { feature, fix, refactor, hotfix }

enum RunStatus {
  queued,
  starting,
  running,

  /// A pause the user asked for, recorded while the active step finishes.
  ///
  /// FR-RC-02 pauses *before the next step*, never mid-step, so the request and
  /// the pause are two distinct states rather than one.
  pauseRequested,
  paused,
  succeeded,
  failed,
  interrupted,
  canceled;

  bool get isTerminal => switch (this) {
    succeeded || failed || interrupted || canceled => true,
    _ => false,
  };

  bool canTransitionTo(RunStatus next) => switch ((this, next)) {
    (queued, starting) || (queued, canceled) => true,
    (starting, running) ||
    (starting, failed) ||
    (starting, interrupted) ||
    (starting, canceled) => true,
    (running, succeeded) ||
    (running, failed) ||
    (running, interrupted) ||
    (running, pauseRequested) ||
    (running, paused) ||
    (running, canceled) => true,
    (pauseRequested, paused) ||
    (pauseRequested, succeeded) ||
    (pauseRequested, failed) ||
    (pauseRequested, interrupted) ||
    (pauseRequested, canceled) => true,
    (paused, running) ||
    (paused, failed) ||
    (paused, interrupted) ||
    (paused, canceled) => true,
    // Recovery re-entry (FR-RC-05..07). The repository adds the evidence
    // guards; the lifecycle only says the move is possible.
    (failed, running) || (canceled, running) || (interrupted, running) => true,
    // Autonomous delivery occurs after the final workflow step has durable
    // success evidence. Its independent gates may safely re-enter a prior
    // step or turn that provisional success into a terminal failure.
    (succeeded, running) || (succeeded, failed) => true,
    _ => false,
  };
}

enum AttemptStatus { starting, running, succeeded, failed, interrupted }

enum RunLogChannel { stdout, stderr, system }

enum RecoveryAction {
  retryWithPreservedContext,
  rerunStepFresh,
  restartWorkflow,
}

enum RecoveryRequestStatus { pending, accepted, rejected }

sealed class RunWorkItem {
  const RunWorkItem();

  Map<String, Object?> toJson();

  String toCanonicalJson() => _encodeCanonical(toJson());

  static RunWorkItem fromCanonicalJson(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?>) {
      throw const FormatException('A run work item must be a JSON object.');
    }
    return switch (value['type']) {
      'useCase' => UseCaseRunWorkItem(
        identifier: _requiredString(value, 'identifier'),
        title: _requiredString(value, 'title'),
      ),
      'githubIssue' => GitHubIssueRunWorkItem(
        repository: _requiredString(value, 'repository'),
        number: _requiredInt(value, 'number'),
        title: _requiredString(value, 'title'),
        url: _requiredString(value, 'url'),
      ),
      'freeFormTask' => FreeFormRunWorkItem(
        text: _requiredString(value, 'text'),
      ),
      _ => throw const FormatException('Unsupported run work-item type.'),
    };
  }
}

final class UseCaseRunWorkItem extends RunWorkItem {
  UseCaseRunWorkItem({required String identifier, required String title})
    : identifier = _nonBlank(identifier, 'identifier'),
      title = _nonBlank(title, 'title');

  final String identifier;
  final String title;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'useCase',
    'identifier': identifier,
    'title': title,
  };
}

final class GitHubIssueRunWorkItem extends RunWorkItem {
  GitHubIssueRunWorkItem({
    required String repository,
    required this.number,
    required String title,
    required String url,
  }) : repository = _nonBlank(repository, 'repository'),
       title = _nonBlank(title, 'title'),
       url = _nonBlank(url, 'url') {
    if (number < 1) {
      throw ArgumentError.value(number, 'number', 'Must be positive.');
    }
  }

  final String repository;
  final int number;
  final String title;
  final String url;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'githubIssue',
    'repository': repository,
    'number': number,
    'title': title,
    'url': url,
  };
}

final class FreeFormRunWorkItem extends RunWorkItem {
  FreeFormRunWorkItem({required String text})
    : text = _bounded(text, 'text', maximumLength);

  static const int maximumLength = 4096;
  final String text;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'freeFormTask',
    'text': text,
  };
}

final class DeclaredContext {
  DeclaredContext._(this.value, this.bytes);

  static const int maximumBytes = 256 * 1024;

  factory DeclaredContext.parse(String value) {
    final byteLength = utf8.encode(value).length;
    if (byteLength > maximumBytes) {
      throw DeclaredContextTooLarge(
        actualBytes: byteLength,
        maximumBytes: maximumBytes,
      );
    }
    return DeclaredContext._(value, byteLength);
  }

  final String value;
  final int bytes;
}

final class DeclaredContextTooLarge implements Exception {
  const DeclaredContextTooLarge({
    required this.actualBytes,
    required this.maximumBytes,
  });

  final int actualBytes;
  final int maximumBytes;

  @override
  String toString() =>
      'DeclaredContextTooLarge(actualBytes: $actualBytes, '
      'maximumBytes: $maximumBytes)';
}

final class RunSnapshotStep {
  RunSnapshotStep({
    required this.id,
    required this.sourceWorkflowStepId,
    required this.position,
    required this.kind,
    required this.name,
    required this.cli,
    required this.model,
    required Map<String, Object?> configuration,
  }) : configuration = _deepImmutableMap(configuration) {
    if (position < 0) throw ArgumentError.value(position, 'position');
    if ((cli == null) != (model == null)) {
      throw ArgumentError('CLI and model must both be present or absent.');
    }
  }

  final String id;
  final String sourceWorkflowStepId;
  final int position;
  final String kind;
  final String name;
  final String? cli;
  final String? model;
  final Map<String, Object?> configuration;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sourceWorkflowStepId': sourceWorkflowStepId,
    'position': position,
    'kind': kind,
    'name': name,
    'cli': cli,
    'model': model,
    'configuration': configuration,
  };

  factory RunSnapshotStep.fromJson(Map<String, Object?> value) =>
      RunSnapshotStep(
        id: _requiredString(value, 'id'),
        sourceWorkflowStepId: _requiredString(value, 'sourceWorkflowStepId'),
        position: _requiredInt(value, 'position'),
        kind: _requiredString(value, 'kind'),
        name: _requiredString(value, 'name'),
        cli: value['cli'] as String?,
        model: value['model'] as String?,
        configuration: _requiredMap(value, 'configuration'),
      );
}

final class RunSnapshot {
  RunSnapshot({
    required this.schemaVersion,
    required this.projectId,
    required this.projectName,
    required this.canonicalSourcePath,
    required this.sourceRevision,
    required this.workflowId,
    required this.workflowRevision,
    required this.workflowName,
    required this.workItem,
    required this.deliveryMode,
    required this.branchWorkType,
    required Iterable<RunSnapshotStep> steps,
  }) : steps = List<RunSnapshotStep>.unmodifiable(
         (steps.toList()..sort((a, b) => a.position.compareTo(b.position))).map(
           (step) => RunSnapshotStep.fromJson(step.toJson()),
         ),
       ) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (workflowRevision < 1) {
      throw ArgumentError.value(workflowRevision, 'workflowRevision');
    }
    if (this.steps.isEmpty) {
      throw ArgumentError.value(
        steps,
        'steps',
        'At least one step is required.',
      );
    }
    for (var index = 0; index < this.steps.length; index++) {
      if (this.steps[index].position != index) {
        throw ArgumentError('Snapshot step positions must be contiguous.');
      }
    }
  }

  final int schemaVersion;
  final String projectId;
  final String projectName;
  final String canonicalSourcePath;
  final String sourceRevision;
  final String workflowId;
  final int workflowRevision;
  final String? workflowName;
  final RunWorkItem workItem;
  final DeliveryMode deliveryMode;
  final BranchWorkType branchWorkType;
  final List<RunSnapshotStep> steps;

  String toCanonicalJson() => _encodeCanonical(<String, Object?>{
    'schemaVersion': schemaVersion,
    'project': <String, Object?>{
      'id': projectId,
      'name': projectName,
      'canonicalSourcePath': canonicalSourcePath,
      'sourceRevision': sourceRevision,
    },
    'workflow': <String, Object?>{
      'id': workflowId,
      'revision': workflowRevision,
      'name': workflowName,
      'steps': steps.map((step) => step.toJson()).toList(growable: false),
    },
    'workItem': workItem.toJson(),
    'deliveryMode': deliveryMode.name,
    'branchWorkType': branchWorkType.name,
  });

  factory RunSnapshot.fromCanonicalJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('A run snapshot must be a JSON object.');
    }
    final project = _requiredMap(decoded, 'project');
    final workflow = _requiredMap(decoded, 'workflow');
    final rawSteps = workflow['steps'];
    if (rawSteps is! List<Object?>) {
      throw const FormatException('Snapshot steps must be a JSON array.');
    }
    return RunSnapshot(
      schemaVersion: _requiredInt(decoded, 'schemaVersion'),
      projectId: _requiredString(project, 'id'),
      projectName: _requiredString(project, 'name'),
      canonicalSourcePath: _requiredString(project, 'canonicalSourcePath'),
      sourceRevision: _requiredString(project, 'sourceRevision'),
      workflowId: _requiredString(workflow, 'id'),
      workflowRevision: _requiredInt(workflow, 'revision'),
      workflowName: workflow['name'] as String?,
      workItem: RunWorkItem.fromCanonicalJson(
        _encodeCanonical(_requiredMap(decoded, 'workItem')),
      ),
      deliveryMode: DeliveryMode.values.byName(
        _requiredString(decoded, 'deliveryMode'),
      ),
      branchWorkType: BranchWorkType.values.byName(
        _requiredString(decoded, 'branchWorkType'),
      ),
      steps: rawSteps.map((value) {
        if (value is! Map<String, Object?>) {
          throw const FormatException('A snapshot step must be an object.');
        }
        return RunSnapshotStep.fromJson(value);
      }),
    );
  }
}

final class WorkflowRun {
  const WorkflowRun({
    required this.id,
    required this.projectId,
    required this.workflowId,
    required this.label,
    required this.status,
    required this.currentStepPosition,
    required this.createdAt,
    required this.updatedAt,
    this.branchName,
    this.worktreePath,
    this.startedAt,
    this.completedAt,
    this.deletedAt,
  });

  final String id;
  final String? projectId;
  final String? workflowId;
  final String label;
  final RunStatus status;
  final int currentStepPosition;
  final String? branchName;
  final String? worktreePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? deletedAt;
}

final class RunAttempt {
  const RunAttempt({
    required this.id,
    required this.runId,
    required this.snapshotStepId,
    required this.attemptNumber,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.exitCode,
    this.failureCode,
    this.declaredContext,
  });

  final String id;
  final String runId;
  final String snapshotStepId;
  final int attemptNumber;
  final AttemptStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? exitCode;
  final String? failureCode;
  final DeclaredContext? declaredContext;
}

final class RunLogSegment {
  RunLogSegment({
    required this.id,
    required this.runId,
    required this.attemptId,
    required this.snapshotStepId,
    required this.sequence,
    required this.channel,
    required Uint8List bytes,
    required this.compression,
    required this.originalByteLength,
    required this.createdAt,
  }) : _bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final String id;
  final String runId;
  final String attemptId;
  final String snapshotStepId;
  final int sequence;
  final RunLogChannel channel;
  final Uint8List _bytes;
  Uint8List get bytes => _bytes;
  final String compression;
  final int originalByteLength;
  final DateTime createdAt;
}

final class RunRecoveryRequest {
  const RunRecoveryRequest({
    required this.id,
    required this.runId,
    required this.attemptId,
    required this.action,
    required this.status,
    required this.requestedAt,
  });

  final String id;
  final String runId;
  final String? attemptId;
  final RecoveryAction action;
  final RecoveryRequestStatus status;
  final DateTime requestedAt;
}

String _nonBlank(String input, String name) {
  final value = input.trim();
  if (value.isEmpty) {
    throw ArgumentError.value(input, name, 'Must not be blank.');
  }
  return value;
}

String _bounded(String input, String name, int maximumLength) {
  final value = _nonBlank(input, name);
  if (value.length > maximumLength) {
    throw ArgumentError.value(
      input,
      name,
      'Exceeds $maximumLength characters.',
    );
  }
  return value;
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('Expected string field $key.');
  return value;
}

int _requiredInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('Expected integer field $key.');
  return value;
}

Map<String, Object?> _requiredMap(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('Expected object field $key.');
  }
  return value;
}

Map<String, Object?> _deepImmutableMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable(
      source.map((key, value) => MapEntry(key, _deepImmutable(value))),
    );

Object? _deepImmutable(Object? value) => switch (value) {
  Map<String, Object?> map => _deepImmutableMap(map),
  List<Object?> list => List<Object?>.unmodifiable(list.map(_deepImmutable)),
  _ => value,
};

String _encodeCanonical(Object? value) => jsonEncode(_sortJson(value));

Object? _sortJson(Object? value) => switch (value) {
  Map<String, Object?> map => <String, Object?>{
    for (final key in (map.keys.toList()..sort())) key: _sortJson(map[key]),
  },
  List<Object?> list => list.map(_sortJson).toList(growable: false),
  _ => value,
};
