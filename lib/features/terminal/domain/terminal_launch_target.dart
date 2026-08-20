import 'package:maestro/features/terminal/domain/terminal_models.dart';

final class TerminalLaunchTarget {
  const TerminalLaunchTarget._({
    required this.label,
    required this.workingDirectory,
    required this.failure,
    required this.isProject,
  });

  factory TerminalLaunchTarget.project({
    required String projectName,
    required String workingDirectory,
  }) => TerminalLaunchTarget._(
    label: projectName,
    workingDirectory: workingDirectory,
    failure: null,
    isProject: true,
  );

  factory TerminalLaunchTarget.home({required String workingDirectory}) =>
      TerminalLaunchTarget._(
        label: 'Home',
        workingDirectory: workingDirectory,
        failure: null,
        isProject: false,
      );

  factory TerminalLaunchTarget.failure(TerminalFailure failure) =>
      TerminalLaunchTarget._(
        label: 'Home',
        workingDirectory: null,
        failure: failure,
        isProject: false,
      );

  final String label;
  final String? workingDirectory;
  final TerminalFailure? failure;
  final bool isProject;
}
