import 'dart:io';

import 'package:maestro/platform/process/process_supervisor.dart';

final class ProcessStartRequest {
  const ProcessStartRequest({
    required this.executable,
    this.arguments = const <String>[],
    this.workingDirectory,
    this.environment = const <String, String>{},
    this.includeParentEnvironment = true,
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final bool includeParentEnvironment;
}

abstract interface class NativeProcessTree {
  Future<OwnedNativeProcess> start(ProcessStartRequest request);
}

abstract interface class GatedNativeProcessTree implements NativeProcessTree {
  Future<OwnedNativeProcess> startOwned(
    ProcessStartRequest request,
    Future<void> Function(OwnedNativeProcess process) beforeRelease,
  );
}

abstract interface class OwnedNativeProcess implements OwnedProcess {
  int get pid;
  Future<int> get exitCode;
  IOSink get stdin;
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
}

Future<Process> startNativeProcess(ProcessStartRequest request) {
  return Process.start(
    request.executable,
    request.arguments,
    workingDirectory: request.workingDirectory,
    environment: request.environment,
    includeParentEnvironment: request.includeParentEnvironment,
    runInShell: false,
  );
}
