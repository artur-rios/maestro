import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/terminal/data/local_terminal_home_directory.dart';
import 'package:maestro/features/terminal/domain/terminal_launch_target.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';

void main() {
  test(
    'GivenWindowsUserProfile_WhenResolved_ThenHomeTargetUsesThatFolder',
    () {
      final resolver = LocalTerminalHomeDirectory(
        environment: <String, String>{'USERPROFILE': r'C:\Users\Ada'},
        isWindows: true,
      );

      final target = resolver.resolve();

      expect(target.label, 'Home');
      expect(target.workingDirectory, r'C:\Users\Ada');
      expect(target.failure, isNull);
    },
  );

  test('GivenUnixHome_WhenResolved_ThenHomeTargetUsesThatFolder', () {
    final target = LocalTerminalHomeDirectory(
      environment: <String, String>{'HOME': '/home/ada'},
      isWindows: false,
    ).resolve();

    expect(target.workingDirectory, '/home/ada');
  });

  test('GivenNoHomeEnvironment_WhenResolved_ThenTypedFailureIsReturned', () {
    final target = LocalTerminalHomeDirectory(
      environment: const <String, String>{},
      isWindows: true,
    ).resolve();

    expect(target.workingDirectory, isNull);
    expect(target.failure?.code, TerminalFailure.folderUnavailableCode);
    expect(target.failure?.remediation, contains('home folder'));
  });

  test(
    'GivenDuplicateSeparators_WhenProjectTargetCreated_ThenNameAndPathStayImmutable',
    () {
      final target = TerminalLaunchTarget.project(
        projectName: 'Maestro',
        workingDirectory: r'D:\Repositories\maestro',
      );

      expect(target.label, 'Maestro');
      expect(target.isProject, isTrue);
      expect(target.workingDirectory, r'D:\Repositories\maestro');
    },
  );
}
