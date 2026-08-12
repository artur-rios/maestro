import 'dart:io';

import '../../lib/platform/updates/release_version.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: validate_release_tag.dart <tag> <github-output-file>',
    );
    exitCode = 64;
    return;
  }

  try {
    final version = ReleaseVersion.parseTag(arguments[0]);
    final output = File(arguments[1]);
    final values = <String, String>{
      'semantic_version': version.semanticVersion,
      'core_version': version.coreVersion,
      'windows_version': version.windowsVersion,
      'debian_version': version.debianVersion,
      'is_prerelease': version.isPrerelease.toString(),
    };
    await output.writeAsString(
      values.entries.map((entry) => '${entry.key}=${entry.value}').join('\n') +
          '\n',
      mode: FileMode.append,
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 65;
  }
}
