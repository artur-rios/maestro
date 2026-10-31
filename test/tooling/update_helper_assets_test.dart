import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/updates/production_update_service.dart';

void main() {
  test(
    'GivenLinuxPackager_WhenProjectionIsMissingOrInvalid_ThenValidationFails',
    () async {
      final script = File('tooling/packaging/.package_linux_$pid.sh');
      addTearDown(() => script.delete());
      await script.writeAsString(
        (await File(
          'tooling/packaging/package_linux.sh',
        ).readAsString()).replaceAll('\r\n', '\n'),
      );
      final bash = Platform.isWindows
          ? r'C:\Program Files\Git\bin\bash.exe'
          : 'bash';
      final scriptArgument = Platform.isWindows
          ? '/${script.absolute.path[0].toLowerCase()}${script.absolute.path.substring(2).replaceAll(r'\', '/')}'
          : script.path;
      final missing = await Process.run(bash, <String>[
        scriptArgument,
        '1.2.3-rc.0',
        '1.2.3',
      ]);
      final invalid = await Process.run(bash, <String>[
        scriptArgument,
        '1.2.3-rc.0',
        '1.2.3-rc.0',
        '1.2.3~rc.0-1',
      ]);

      expect(missing.exitCode, isNot(0));
      expect('${missing.stderr}', contains('debian version is required'));
      expect(invalid.exitCode, 65);
      expect('${invalid.stderr}', contains('CoreVersion'));
    },
  );

  test(
    'GivenLinuxPrereleaseProjections_WhenPreflightRuns_ThenCanonicalRoutingIsReported',
    () async {
      final script = File(
        'tooling/packaging/.package_linux_${pid}_positive.sh',
      );
      addTearDown(() => script.delete());
      await script.writeAsString(
        (await File(
          'tooling/packaging/package_linux.sh',
        ).readAsString()).replaceAll('\r\n', '\n'),
      );
      final environment = Map<String, String>.of(Platform.environment)
        ..['MAESTRO_PACKAGING_PREFLIGHT_ONLY'] = '1';
      final scriptArgument = Platform.isWindows
          ? '/${File(script.absolute.path).path[0].toLowerCase()}${script.absolute.path.substring(2).replaceAll(r'\', '/')}'
          : script.path;
      final result = await Process.run(
        Platform.isWindows ? r'C:\Program Files\Git\bin\bash.exe' : 'bash',
        <String>[scriptArgument, '1.2.3-rc.4', '1.2.3', '1.2.3~rc.4'],
        environment: environment,
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}', contains('semantic_version=1.2.3-rc.4'));
      expect('${result.stdout}', contains('debian_version=1.2.3~rc.4'));
    },
  );

  test(
    'GivenAppImageHelper_WhenInvokedWithTwoArguments_ThenItRefuses',
    () async {
      // The installer passes package, install path and parent pid. A helper
      // that silently accepted fewer would hide exactly the mismatch that made
      // Linux self-update impossible.
      if (!Platform.isLinux && !Platform.isMacOS) return;
      final result = await Process.run('/bin/bash', <String>[
        'tooling/updates/replace_linux_appimage.sh',
        '/tmp/maestro-absent.AppImage',
        '/tmp/maestro-absent',
      ], runInShell: false);

      expect(result.exitCode, 64);
      expect('${result.stderr}', contains('<parent_pid>'));
    },
  );

  group('replace_linux_appimage.sh', () {
    late Directory work;
    late File installed;
    late File staged;
    late File marker;

    setUp(() async {
      work = await Directory.systemTemp.createTemp('maestro-appimage-update-');
      installed = File('${work.path}/Applications/maestro-linux-x64.AppImage');
      await installed.parent.create();
      await installed.writeAsString('#!/bin/sh\necho old\n');
      await Process.run('chmod', <String>['0750', installed.path]);
      // The downloader stages the package with ordinary file permissions.
      staged = File('${work.path}/updates/${'a' * 64}.appimage');
      await staged.parent.create();
      await staged.writeAsString(
        '#!/bin/sh\nprintf "%s" "\$0" > "\$MAESTRO_TEST_MARKER"\n',
      );
      marker = File('${work.path}/relaunched');
    });

    tearDown(() async {
      if (await work.exists()) await work.delete(recursive: true);
    });

    Future<ProcessResult> replace({required int parentPid}) => Process.run(
      '/bin/bash',
      <String>[
        'tooling/updates/replace_linux_appimage.sh',
        staged.path,
        installed.path,
        '$parentPid',
      ],
      environment: <String, String>{'MAESTRO_TEST_MARKER': marker.path},
    );

    test(
      'GivenAStagedAppImage_WhenMaestroExits_ThenTheAppImageFileIsReplacedInPlaceAndRelaunched',
      () async {
        if (!Platform.isLinux) return;
        final parent = await Process.start('sleep', <String>['1']);

        final replacing = replace(parentPid: parent.pid);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(
          await installed.readAsString(),
          '#!/bin/sh\necho old\n',
          reason: 'nothing is replaced while Maestro is still running',
        );
        final result = await replacing;

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(await installed.readAsString(), await staged.readAsString());
        final mode = await Process.run('stat', <String>[
          '-c',
          '%a',
          installed.path,
        ]);
        expect(
          '${mode.stdout}'.trim(),
          '750',
          reason: 'the installed file keeps its permissions, execute included',
        );
        expect(await marker.readAsString(), installed.path);
        expect(
          installed.parent.listSync().map((entity) => entity.path),
          <String>[installed.path],
          reason: 'no staging file is left beside the AppImage',
        );
      },
    );

    test(
      'GivenTheReplacementCannotBeStaged_WhenUpdating_ThenTheInstalledAppImageIsUntouchedAndNotRelaunched',
      () async {
        if (!Platform.isLinux) return;
        await Directory(
          '${installed.path}.staging/occupied',
        ).create(recursive: true);
        final parent = await Process.start('true', const <String>[]);
        await parent.exitCode;

        final result = await replace(parentPid: parent.pid);

        expect(result.exitCode, isNot(0));
        expect(await installed.readAsString(), '#!/bin/sh\necho old\n');
        expect(await marker.exists(), isFalse);
      },
    );

    test(
      'GivenNoInstalledAppImage_WhenUpdating_ThenTheHelperRefusesBeforeWaitingForMaestro',
      () async {
        if (!Platform.isLinux) return;
        await installed.delete();
        final parent = await Process.start('sleep', <String>['30']);
        addTearDown(parent.kill);

        final result = await replace(
          parentPid: parent.pid,
        ).timeout(const Duration(seconds: 10));

        expect(result.exitCode, 66);
        expect('${result.stderr}', contains('Installed AppImage'));
        expect(await installed.exists(), isFalse);
      },
    );
  });

  test(
    'GivenTheApplicationIcon_WhenInspected_ThenEveryPlatformAssetIsPresent',
    () async {
      // A missing size is invisible until a shell picks exactly that one, so
      // the set is asserted rather than trusted.
      const sizes = <int>[16, 24, 32, 48, 64, 128, 256, 512, 1024];
      for (final size in sizes) {
        final png = File('tooling/packaging/icons/maestro-$size.png');
        expect(
          await png.exists(),
          isTrue,
          reason: '${png.path} must be generated',
        );
        expect(await png.length(), greaterThan(0));
      }

      final svg = await File('tooling/packaging/maestro.svg').readAsString();
      expect(svg, contains('viewBox="0 0 128 128"'));
      // The mark is the application's own accent, not a stock template colour.
      expect(svg, contains('#B9C3FF'));

      final ico = await File(
        'windows/runner/resources/app_icon.ico',
      ).readAsBytes();
      expect(ico.length, greaterThan(0));
      // An ICO header is: reserved 0, type 1, then the image count.
      expect(ico[0] | ico[1], 0);
      expect(ico[2] | (ico[3] << 8), 1);
      expect(ico[4] | (ico[5] << 8), sizes.length - 2);

      final linuxPackage = await File(
        'tooling/packaging/package_linux.sh',
      ).readAsString();
      expect(linuxPackage, contains('hicolor/scalable/apps/maestro.svg'));
      expect(linuxPackage, contains(r'maestro-$size.png'));

      final pubspec = await File('pubspec.yaml').readAsString();
      expect(
        pubspec,
        contains('logo_path: tooling/packaging/icons/maestro-1024.png'),
      );
      // Trimming would crop the tile's rounded corners away.
      expect(pubspec, contains('trim_logo: false'));

      // The Linux window falls back to the bundled copy wherever no installed
      // icon theme carries the mark, which is every build nobody installed.
      final bundled = File('assets/icons/maestro.png');
      expect(
        await bundled.exists(),
        isTrue,
        reason: '${bundled.path} must be generated',
      );
      expect(await bundled.length(), greaterThan(0));
      expect(pubspec, contains('- assets/icons/maestro.png'));

      final linuxRunner = await File(
        'linux/runner/my_application.cc',
      ).readAsString();
      expect(linuxRunner, contains('gtk_window_set_icon_name(window,'));
      expect(linuxRunner, contains('gtk_window_set_icon_from_file'));
      // The fallback has to name the path the bundle actually ships.
      expect(linuxRunner, contains('"data", "flutter_assets", "assets"'));
    },
  );

  test(
    'GivenPackagingScripts_WhenInspected_ThenReleaseDefinesAreForwarded',
    () async {
      // Without these the shipped build composes no update service at all, and
      // the whole signed-update path is unreachable in every release.
      final windows = await File(
        'tooling/packaging/package_windows.ps1',
      ).readAsString();
      final linux = await File(
        'tooling/packaging/package_linux.sh',
      ).readAsString();
      for (final define in ReleaseUpdateConfiguration.requiredDefines) {
        expect(
          windows,
          contains('--dart-define=$define='),
          reason: 'package_windows.ps1 must forward $define',
        );
        expect(
          linux,
          contains('--dart-define=$define='),
          reason: 'package_linux.sh must forward $define',
        );
      }
      // All or nothing: a half-configured build would ship an updater that
      // cannot verify what it downloads.
      expect(windows, contains('runtime-updates: unconfigured'));
      expect(linux, contains('runtime-updates: unconfigured'));
    },
  );

  test(
    'GivenBundledUpdateHelpers_WhenInspected_ThenRollbackAndRelaunchAreDefined',
    () async {
      final windows = await File(
        'tooling/updates/replace_windows_zip.ps1',
      ).readAsString();
      final linux = await File(
        'tooling/updates/replace_linux_appimage.sh',
      ).readAsString();
      final windowsPackage = await File(
        'tooling/packaging/package_windows.ps1',
      ).readAsString();
      final linuxPackage = await File(
        'tooling/packaging/package_linux.sh',
      ).readAsString();
      expect(
        windows,
        allOf(<Matcher>[
          contains('Rollback'),
          contains('ParentProcessId'),
          contains('RelaunchPath'),
          contains(r'Start-Process -FilePath $relaunch -ArgumentList @('),
          contains('windows-zip-update: relaunched'),
          contains(r'Move-Item -LiteralPath $install -Destination $staging'),
          contains(r'Move-Item -LiteralPath $rollback -Destination $install'),
        ]),
      );
      expect(
        linux,
        allOf(<Matcher>[
          contains('parent-pid'),
          // One rename(2) swaps the file: never missing, never partial.
          contains(r'mv -f -- "$staging" "$install_path"'),
          contains(r'chmod --reference="$install_path"'),
          contains(r'exec "$install_path"'),
        ]),
      );
      expect(windowsPackage, contains('replace_windows_zip.ps1'));
      expect(linuxPackage, contains('replace_linux_appimage.sh'));

      final transactionSetup = windows.substring(
        windows.indexOf(r'$transactionId ='),
        windows.indexOf(r'New-Item -ItemType Directory -Path $staging'),
      );
      expect(transactionSetup, contains(r'$rollbackCreated = $false'));
      expect(
        transactionSetup,
        contains('Stale ZIP transaction paths could not be removed.'),
      );
      expect(transactionSetup, isNot(contains('SilentlyContinue')));
      expect(windows, contains(r'$rollbackCreated = $true'));
      expect(windows, contains(r'if ($rollbackCreated)'));
      expect(windows, contains(r'$lockStream = [IO.File]::Open('));
      expect(windows, contains(r'[IO.FileShare]::None'));
      expect(
        windows,
        contains(r"Join-Path $env:LOCALAPPDATA 'Maestro\UpdateLocks'"),
      );
      expect(windows, contains('windows-zip-update: lock acquired'));
      expect(windows, contains('windows-zip-update: busy'));
      expect(windows, contains(r'$transactionId = [Guid]::NewGuid()'));
      expect(windows, contains(r'"$leaf.rollback.$transactionId"'));
      expect(windows, contains(r'"$leaf.staging.$transactionId"'));
      expect(windows, contains('--maestro-update-ready'));
      expect(windows, contains('windows-zip-update: ready'));
      expect(windows, contains(r'$relaunchProcess.HasExited'));
      expect(windows, contains('readiness timed out'));
      expect(
        windows,
        isNot(contains(r'$rollback = Join-Path $parent "$leaf.rollback"')),
      );
    },
  );
}
