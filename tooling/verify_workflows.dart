import 'dart:io';

import 'package:yaml/yaml.dart';

Future<void> main() async {
  final workflowDirectory = Directory('.github/workflows');
  final workflows = await workflowDirectory
      .list()
      .where((entity) => entity is File && entity.path.endsWith('.yml'))
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
    r'\b(?:curl|wget|Invoke-WebRequest|Start-BitsTransfer)\b',
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
    if (workflow.path.endsWith('release.yml')) {
      _verifyReleaseWorkflow(document, workflow.path);
    }
  }
  stdout.writeln('workflow-verification: passed');
}

void _verifyReleaseWorkflow(YamlMap document, String workflowPath) {
  final jobs = document['jobs'] as YamlMap;
  final validation = _job(jobs, 'validate-release', workflowPath);
  final windowsPackage = _job(jobs, 'windows-package', workflowPath);
  final linuxPackage = _job(jobs, 'linux-package', workflowPath);
  final release = _job(jobs, 'release', workflowPath);

  _requireMap(document['permissions'], const <String, Object?>{
    'contents': 'read',
  }, '$workflowPath top-level permissions');
  _requireMap(document['concurrency'], const <String, Object?>{
    'group': r'release-${{ github.ref }}',
    'cancel-in-progress': false,
  }, '$workflowPath concurrency');
  for (final entry in jobs.entries) {
    if (entry.key != 'release' &&
        entry.value is YamlMap &&
        (entry.value as YamlMap)['permissions'] != null) {
      throw FormatException(
        '$workflowPath ${entry.key} must not elevate job permissions.',
      );
    }
  }

  const outputNames = <String>[
    'semantic_version',
    'core_version',
    'windows_version',
    'debian_version',
    'is_prerelease',
  ];
  _requireMap(validation['outputs'], <String, Object?>{
    for (final name in outputNames)
      name:
          r'${{ steps.version.outputs.'
          '$name }}',
  }, '$workflowPath validate-release outputs');
  final validationSteps = _steps(
    validation,
    'validate-release',
    workflowPath,
  ).toList();
  final validationStep = validationSteps
      .where((step) => step['id'] == 'version')
      .firstOrNull;
  final checkoutIndex = validationSteps.indexWhere(
    (step) => '${step['uses']}'.startsWith('actions/checkout@'),
  );
  final flutterIndex = validationSteps.indexWhere(
    (step) =>
        '${step['uses']}'.startsWith('subosito/flutter-action@') &&
        step['with'] is YamlMap &&
        (step['with'] as YamlMap)['flutter-version'] == '3.44.8' &&
        (step['with'] as YamlMap)['channel'] == 'stable' &&
        (step['with'] as YamlMap)['cache'] == true,
  );
  final pubGetIndex = validationSteps.indexWhere(
    (step) => step['run'] == 'flutter pub get',
  );
  final validatorIndex = validationStep == null
      ? -1
      : validationSteps.indexOf(validationStep);
  if (validation['runs-on'] != 'ubuntu-24.04' ||
      checkoutIndex < 0 ||
      flutterIndex <= checkoutIndex ||
      pubGetIndex <= flutterIndex ||
      validatorIndex <= pubGetIndex ||
      validationStep?['run'] !=
          r'dart tooling/release/validate_release_tag.dart "$GITHUB_REF_NAME" "$GITHUB_OUTPUT"') {
    throw FormatException(
      '$workflowPath validate-release must run the tag validator.',
    );
  }

  _requireNeeds(
    windowsPackage,
    const <String>{'validate-release'},
    'windows-package',
    workflowPath,
  );
  _requireNeeds(
    linuxPackage,
    const <String>{'validate-release'},
    'linux-package',
    workflowPath,
  );
  _requireNeeds(
    release,
    const <String>{'validate-release', 'windows-package', 'linux-package'},
    'release',
    workflowPath,
  );

  const semantic = r"${{ needs['validate-release'].outputs.semantic_version }}";
  const core = r"${{ needs['validate-release'].outputs.core_version }}";
  const windows = r"${{ needs['validate-release'].outputs.windows_version }}";
  const debian = r"${{ needs['validate-release'].outputs.debian_version }}";
  const prerelease = r"${{ needs['validate-release'].outputs.is_prerelease }}";
  _requireCommandArguments(
    _steps(windowsPackage, 'windows-package', workflowPath),
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
  _requireCommandArguments(
    _steps(linuxPackage, 'linux-package', workflowPath),
    'tooling/packaging/package_linux.sh',
    <String>[semantic, core, debian],
    workflowPath,
  );

  _verifyUpload(windowsPackage, 'windows-packages', const <String>{
    'dist/maestro-windows-x64.zip',
    'dist/maestro-windows-x64.msix',
    'dist/maestro-windows-x64-setup.exe',
  }, workflowPath);
  _verifyUpload(linuxPackage, 'linux-packages', const <String>{
    'dist/maestro-linux-x64.AppImage',
    'dist/maestro-linux-amd64.deb',
  }, workflowPath);

  _requireMap(release['permissions'], const <String, Object?>{
    'contents': 'write',
    'id-token': 'write',
    'attestations': 'write',
  }, '$workflowPath release permissions');
  final releaseSteps = _steps(release, 'release', workflowPath).toList();
  final manifestStep = releaseSteps
      .where(
        (step) => step['name'] == 'Create and optionally sign release manifest',
      )
      .firstOrNull;
  final manifestCommand = manifestStep?['run'];
  if (manifestCommand is! String ||
      !_hasFailClosedSigning(manifestCommand, semantic)) {
    throw FormatException(
      '$workflowPath release must fail on incomplete signing material and verify exact artifacts.',
    );
  }

  final attestationIndex = releaseSteps.indexWhere(
    (step) => '${step['uses']}'.startsWith('actions/attest-build-provenance@'),
  );
  final publicationIndex = releaseSteps.indexWhere(
    (step) => '${step['uses']}'.startsWith('softprops/action-gh-release@'),
  );
  final manifestIndex = manifestStep == null
      ? -1
      : releaseSteps.indexOf(manifestStep);
  final attestationInputs = attestationIndex < 0
      ? null
      : releaseSteps[attestationIndex]['with'];
  if (manifestIndex < 0 ||
      attestationIndex <= manifestIndex ||
      publicationIndex <= attestationIndex ||
      attestationInputs is! YamlMap ||
      attestationInputs['subject-path'] != 'dist/*') {
    throw FormatException(
      '$workflowPath must attest artifacts before release publication.',
    );
  }
  final publicationInputs = releaseSteps[publicationIndex]['with'];
  _requireMap(publicationInputs, const <String, Object?>{
    'name': r'${{ github.ref_name }}',
    'generate_release_notes': true,
    'prerelease': prerelease,
    'files': 'dist/*',
    'fail_on_unmatched_files': true,
  }, '$workflowPath release publication inputs');
}

bool _hasFailClosedSigning(String command, String semanticVersion) {
  const bothPresent =
      r'[[ -n "$MAESTRO_RELEASE_SECRET_KEY_BASE64" && -n "$MAESTRO_RELEASE_PUBLIC_KEY_BASE64" ]]';
  const sign = 'dart run tooling/release/sign_manifest.dart dist';
  const bothEmpty =
      r'[[ -z "$MAESTRO_RELEASE_SECRET_KEY_BASE64" && -z "$MAESTRO_RELEASE_PUBLIC_KEY_BASE64" ]]';
  const unsigned = "echo 'publisher-signing: unconfigured'";
  const incomplete =
      "echo 'publisher-signing: incomplete signing material' >&2";
  const failure = 'exit 1';
  const branchEnd = '\nfi';
  const verify = 'dart run tooling/release/verify_release.dart dist';
  final createIndex = command.indexOf(
    'dart run tooling/release/create_manifest.dart dist "$semanticVersion"',
  );
  final presentIndex = command.indexOf(bothPresent, createIndex + 1);
  final signIndex = command.indexOf(sign, presentIndex + 1);
  final emptyIndex = command.indexOf(bothEmpty, signIndex + 1);
  final unsignedIndex = command.indexOf(unsigned, emptyIndex + 1);
  final incompleteIndex = command.indexOf(incomplete, unsignedIndex + 1);
  final failureIndex = command.indexOf(failure, incompleteIndex + 1);
  final endIndex = command.indexOf(branchEnd, failureIndex + 1);
  final verifyIndex = command.indexOf(verify, endIndex + 1);
  return createIndex >= 0 &&
      presentIndex > createIndex &&
      signIndex > presentIndex &&
      command.indexOf(sign, signIndex + 1) < 0 &&
      emptyIndex > signIndex &&
      unsignedIndex > emptyIndex &&
      incompleteIndex > unsignedIndex &&
      failureIndex > incompleteIndex &&
      endIndex > failureIndex &&
      verifyIndex > endIndex;
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

void _requireNeeds(
  YamlMap job,
  Set<String> expected,
  String jobName,
  String workflowPath,
) {
  final value = job['needs'];
  final actual = value is YamlList
      ? value.whereType<String>().toSet()
      : value is String
      ? <String>{value}
      : const <String>{};
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw FormatException('$workflowPath $jobName needs must equal $expected.');
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
