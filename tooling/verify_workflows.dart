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
  final releaseAssetReference = RegExp(
    r'''https://github\.com/[^/\s"']+/[^/\s"']+/releases/(?:download/([^/\s"']+)/[^\s"']+|latest/download/[^\s"']+)''',
  );
  final immutableVersion = RegExp(r'^v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$');
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
    for (final match in releaseAssetReference.allMatches(source)) {
      final version = match.group(1);
      if (version == null || !immutableVersion.hasMatch(version)) {
        throw FormatException(
          '${workflow.path} downloads a mutable release asset: ${match.group(0)}',
        );
      }
    }
  }
  stdout.writeln('workflow-verification: passed');
}
