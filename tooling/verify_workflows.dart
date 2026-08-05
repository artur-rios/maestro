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
  }
  stdout.writeln('workflow-verification: passed');
}
