import 'dart:collection';
import 'dart:io';

import 'package:maestro/platform/process/process_supervisor.dart';
import 'package:uuid/uuid_value.dart';

final class RunExecutionContext {
  RunExecutionContext._({
    required this.runId,
    required this.workingDirectory,
    required this.environment,
    required this.supervisor,
  });

  factory RunExecutionContext.create({
    required UuidValue runId,
    required Directory workingDirectory,
    required Map<String, String> environment,
  }) {
    return RunExecutionContext._(
      runId: runId,
      workingDirectory: workingDirectory,
      environment: UnmodifiableMapView<String, String>(
        Map<String, String>.of(environment),
      ),
      supervisor: ProcessSupervisor(),
    );
  }

  final UuidValue runId;
  final Directory workingDirectory;
  final Map<String, String> environment;
  final ProcessSupervisor supervisor;
}
