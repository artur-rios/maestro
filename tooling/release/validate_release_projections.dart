import 'dart:io';

import 'package:maestro/platform/updates/release_version.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length.isEven) {
    stderr.writeln(
      'Usage: validate_release_projections.dart <semantic> '
      '[--core <version>] [--windows <version>] [--debian <version>]',
    );
    exitCode = 64;
    return;
  }

  try {
    final version = ReleaseVersion.parse(arguments.first);
    final supplied = <String, String>{};
    for (var index = 1; index < arguments.length; index += 2) {
      final option = arguments[index];
      if (!const <String>{'--core', '--windows', '--debian'}.contains(option) ||
          supplied.containsKey(option)) {
        throw const FormatException('Unknown or duplicate projection option.');
      }
      supplied[option] = arguments[index + 1];
    }
    _requireMatch('CoreVersion', supplied['--core'], version.coreVersion);
    _requireMatch(
      'WindowsVersion',
      supplied['--windows'],
      version.windowsVersion,
    );
    _requireMatch('DebianVersion', supplied['--debian'], version.debianVersion);
    stdout.write(
      'semantic_version=${version.semanticVersion}\n'
      'core_version=${version.coreVersion}\n'
      'windows_version=${version.windowsVersion}\n'
      'debian_version=${version.debianVersion}\n',
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 65;
  }
}

void _requireMatch(String name, String? supplied, String expected) {
  if (supplied != null && supplied != expected) {
    throw FormatException(
      '$name mismatch: expected $expected, found $supplied.',
    );
  }
}
