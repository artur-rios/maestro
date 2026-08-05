import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:maestro/platform/updates/windows_package_installer.dart';

void main() {
  test(
    'GivenWindowsZip_WhenInstalling_ThenDetachedHelperReceivesExactPath',
    () async {
      final runner = _RecordingRunner();
      final installer = WindowsPackageInstaller(
        runner: runner,
        zipReplacementHelper: r'C:\maestro\replace_windows_zip.ps1',
      );
      final artifact = ReleaseArtifact(
        platform: 'windows',
        architecture: 'x64',
        packageType: 'zip',
        url: Uri.parse('https://example.test/maestro.zip'),
        size: 42,
        sha256: 'a' * 64,
      );

      final result = await installer.install(
        StagedUpdate(artifact: artifact, path: r'C:\staged\maestro.zip'),
      );

      expect(result, isA<Success<void>>());
      expect(runner.requests.single.executable, 'powershell.exe');
      expect(
        runner.requests.single.arguments,
        contains(r'C:\staged\maestro.zip'),
      );
    },
  );
}

final class _RecordingRunner implements CommandRunner {
  final List<CommandRequest> requests = <CommandRequest>[];

  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    return const CommandResult(exitCode: 0, stdout: '', stderr: '');
  }
}
