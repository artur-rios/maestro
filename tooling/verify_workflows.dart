import 'dart:io';

import 'package:yaml/yaml.dart';

Future<void> main() async {
  final workflowDirectory = Directory('.github/workflows');
  final workflows = await workflowDirectory
      .list()
      // GitHub runs `.yaml` workflows too; skipping them would leave a whole
      // workflow unchecked for mutable actions and downloads.
      .where(
        (entity) =>
            entity is File &&
            (entity.path.endsWith('.yml') || entity.path.endsWith('.yaml')),
      )
      .cast<File>()
      .toList();
  if (workflows.isEmpty) {
    throw StateError('No GitHub Actions workflows were found.');
  }
  final actionReference = RegExp(r'uses:\s*[^@\s]+@([^\s#]+)');
  final immutableSha = RegExp(r'^[0-9a-fA-F]{40}$');
  final immutableReleaseAsset = RegExp(
    r'''^https?://[^\s"']+/releases/download/([^/\s"']+)/[^\s"']+$''',
  );
  final immutableVersion = RegExp(r'^v?\d+\.\d+\.\d+$');
  final downloadCommand = RegExp(
    r'\b(?:curl|wget|Invoke-WebRequest|Invoke-RestMethod|iwr|irm|Start-BitsTransfer)\b',
    caseSensitive: false,
  );
  final httpUrl = RegExp(r'''https?://[^\s"']+''');
  for (final workflow in workflows) {
    final source = await workflow.readAsString();
    final document = loadYaml(source);
    if (document is! YamlMap || document['jobs'] is! YamlMap) {
      throw FormatException('${workflow.path} has no jobs map.');
    }
    for (final match in actionReference.allMatches(source)) {
      final reference = match.group(1)!;
      if (!immutableSha.hasMatch(reference)) {
        throw FormatException(
          '${workflow.path} uses a mutable action reference: $reference',
        );
      }
    }
    for (final job
        in (document['jobs'] as YamlMap).values.whereType<YamlMap>()) {
      final steps = job['steps'];
      if (steps is! YamlList) {
        continue;
      }
      for (final step in steps.whereType<YamlMap>()) {
        final command = step['run'];
        if (command is! String || !downloadCommand.hasMatch(command)) {
          continue;
        }
        final urls = httpUrl
            .allMatches(command)
            .map((match) => match.group(0)!);
        if (urls.isEmpty) {
          throw FormatException(
            '${workflow.path} downloads an executable without an immutable release URL.',
          );
        }
        for (final url in urls) {
          final match = immutableReleaseAsset.firstMatch(url);
          final version = match?.group(1);
          if (version == null || !immutableVersion.hasMatch(version)) {
            throw FormatException(
              '${workflow.path} downloads a mutable release asset: $url',
            );
          }
        }
      }
    }
    if (workflow.path.endsWith('release-windows.yml')) {
      _verifyWindowsReleaseWorkflow(document, workflow.path);
    }
  }
  stdout.writeln('workflow-verification: passed');
}

/// The Windows half of a release. Jenkins dispatches this workflow on the
/// release tag (release.windows in yggdrasil.yml); the Linux half, the manifest
/// and the publication are Jenkins's, so what is checked here is that this
/// workflow still validates the tag, packages from the projections it yields,
/// forwards the updater configuration and uploads exactly the Windows packages.
void _verifyWindowsReleaseWorkflow(YamlMap document, String workflowPath) {
  final jobs = document['jobs'] as YamlMap;
  final windowsPackage = _job(jobs, 'windows-package', workflowPath);

  _requireMap(document['permissions'], const <String, Object?>{
    'contents': 'read',
  }, '$workflowPath top-level permissions');
  _requireMap(document['concurrency'], const <String, Object?>{
    'group': r'release-windows-${{ inputs.tag }}',
    'cancel-in-progress': false,
  }, '$workflowPath concurrency');
  for (final entry in jobs.entries) {
    if (entry.value is YamlMap &&
        (entry.value as YamlMap)['permissions'] != null) {
      throw FormatException(
        '$workflowPath ${entry.key} must not elevate job permissions.',
      );
    }
  }
  // Jenkins starts it with a tag and nothing else; it is not a CI check.
  final trigger = document['on'];
  final dispatch = trigger is YamlMap ? trigger['workflow_dispatch'] : null;
  final inputs = dispatch is YamlMap ? dispatch['inputs'] : null;
  final tagInput = inputs is YamlMap ? inputs['tag'] : null;
  if (trigger is! YamlMap ||
      trigger.length != 1 ||
      inputs is! YamlMap ||
      inputs.length != 1 ||
      tagInput is! YamlMap ||
      tagInput['required'] != true) {
    throw FormatException(
      '$workflowPath must run only on workflow_dispatch with a required tag input.',
    );
  }

  final steps = _steps(
    windowsPackage,
    'windows-package',
    workflowPath,
  ).toList();
  final checkoutIndex = steps.indexWhere(
    (step) => '${step['uses']}'.startsWith('actions/checkout@'),
  );
  final flutterIndex = steps.indexWhere(
    (step) =>
        '${step['uses']}'.startsWith('subosito/flutter-action@') &&
        step['with'] is YamlMap &&
        (step['with'] as YamlMap)['flutter-version'] == '3.47.2' &&
        (step['with'] as YamlMap)['channel'] == 'stable' &&
        (step['with'] as YamlMap)['cache'] == true,
  );
  final pubGetIndex = steps.indexWhere(
    (step) => step['run'] == 'flutter pub get',
  );
  final validatorIndex = steps.indexWhere((step) => step['id'] == 'version');
  if (windowsPackage['runs-on'] != 'windows-2025' ||
      checkoutIndex < 0 ||
      flutterIndex <= checkoutIndex ||
      pubGetIndex <= flutterIndex ||
      validatorIndex <= pubGetIndex ||
      steps[validatorIndex]['run'] !=
          r'dart tooling/release/validate_release_tag.dart "$env:RELEASE_TAG" "$env:GITHUB_OUTPUT"') {
    throw FormatException(
      '$workflowPath windows-package must run the tag validator.',
    );
  }

  // A packaged build without these carries no runtime updater at all, which is
  // exactly the silent regression this check exists to prevent.
  _requireReleaseUpdateEnvironment(
    windowsPackage,
    'windows-package',
    workflowPath,
  );

  const semantic = r'${{ steps.version.outputs.semantic_version }}';
  const core = r'${{ steps.version.outputs.core_version }}';
  const windows = r'${{ steps.version.outputs.windows_version }}';
  _requireCommandArguments(
    steps,
    'tooling/packaging/package_windows.ps1',
    <String>[
      '-SemanticVersion',
      semantic,
      '-CoreVersion',
      core,
      '-WindowsVersion',
      windows,
    ],
    workflowPath,
  );
  _verifyUpload(windowsPackage, 'maestro-windows-packages', const <String>{
    'dist/maestro-windows-x64.zip',
    'dist/maestro-windows-x64.msix',
    'dist/maestro-windows-x64-setup.exe',
  }, workflowPath);
}

/// Requires a packaging job to forward the defines that enable the updater.
void _requireReleaseUpdateEnvironment(
  YamlMap job,
  String jobName,
  String workflowPath,
) {
  const expected = <String, String>{
    'MAESTRO_RELEASE_PUBLIC_KEY_BASE64':
        r'${{ secrets.MAESTRO_RELEASE_PUBLIC_KEY_BASE64 }}',
    'MAESTRO_RELEASE_MANIFEST_URL': r'${{ vars.MAESTRO_RELEASE_MANIFEST_URL }}',
    'MAESTRO_RELEASE_SIGNATURE_URL':
        r'${{ vars.MAESTRO_RELEASE_SIGNATURE_URL }}',
  };
  final environment = job['env'];
  if (environment is! YamlMap ||
      expected.entries.any((entry) => environment[entry.key] != entry.value)) {
    throw FormatException(
      '$workflowPath $jobName must forward the release update configuration.',
    );
  }
}

YamlMap _job(YamlMap jobs, String name, String workflowPath) {
  final job = jobs[name];
  if (job is! YamlMap) {
    throw FormatException('$workflowPath has no $name job.');
  }
  return job;
}

Iterable<YamlMap> _steps(YamlMap job, String name, String workflowPath) {
  final steps = job['steps'];
  if (steps is! YamlList) {
    throw FormatException('$workflowPath has no $name steps.');
  }
  return steps.whereType<YamlMap>();
}

void _requireMap(Object? value, Map<String, Object?> expected, String label) {
  if (value is! YamlMap ||
      value.length != expected.length ||
      expected.entries.any((entry) => value[entry.key] != entry.value)) {
    throw FormatException('$label must equal $expected.');
  }
}

void _requireCommandArguments(
  Iterable<YamlMap> steps,
  String commandName,
  List<String> arguments,
  String workflowPath,
) {
  final command = steps
      .map((step) => step['run'])
      .whereType<String>()
      .where((run) => run.contains(commandName))
      .firstOrNull;
  if (command == null ||
      arguments.any((argument) => !command.contains(argument))) {
    throw FormatException(
      '$workflowPath $commandName must consume validated version projections.',
    );
  }
}

void _verifyUpload(
  YamlMap job,
  String artifactName,
  Set<String> expectedPaths,
  String workflowPath,
) {
  final upload = _steps(job, artifactName, workflowPath)
      .whereType<YamlMap>()
      .where(
        (step) =>
            step['uses'] is String &&
            (step['uses'] as String).startsWith('actions/upload-artifact@') &&
            step['with'] is YamlMap &&
            (step['with'] as YamlMap)['name'] == artifactName,
      )
      .firstOrNull;
  final uploadInputs = upload?['with'];
  final paths = uploadInputs is YamlMap ? uploadInputs['path'] : null;
  final actualPaths = paths is String
      ? paths
            .split(RegExp(r'\r?\n'))
            .map((path) => path.trim())
            .where((path) => path.isNotEmpty)
            .toSet()
      : const <String>{};
  if (uploadInputs is! YamlMap ||
      actualPaths.length != expectedPaths.length ||
      !actualPaths.containsAll(expectedPaths) ||
      uploadInputs['if-no-files-found'] != 'error') {
    throw FormatException(
      '$workflowPath $artifactName upload must contain the exact artifact paths and fail when absent.',
    );
  }
}
