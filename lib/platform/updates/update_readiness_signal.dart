import 'dart:io';

import 'package:path/path.dart' as p;

abstract interface class UpdateReadinessSignalWriter {
  Future<void> write(String path);
}

final class IoUpdateReadinessSignalWriter
    implements UpdateReadinessSignalWriter {
  const IoUpdateReadinessSignalWriter();

  @override
  Future<void> write(String path) async {
    final temporary = File('$path.tmp');
    await temporary.writeAsString('ready', flush: true);
    await temporary.rename(path);
  }
}

final class UpdateReadinessSignal {
  const UpdateReadinessSignal._(this.path);

  static const String argument = '--maestro-update-ready';
  static final p.Context _windows = p.Context(style: p.Style.windows);

  final String path;

  static UpdateReadinessSignal? parse({
    required List<String> arguments,
    required String executablePath,
  }) {
    if (arguments.length != 2 || arguments.first != argument) return null;
    final executable = _windows.normalize(executablePath);
    final candidate = _windows.normalize(arguments.last);
    if (!_windows.isAbsolute(executable) || !_windows.isAbsolute(candidate)) {
      return null;
    }
    if (_windows.dirname(candidate).toLowerCase() !=
        _windows.dirname(executable).toLowerCase()) {
      return null;
    }
    final name = _windows.basename(candidate);
    if (!RegExp(
      r'^\.maestro-update-ready-[0-9a-f]+\.signal$',
      caseSensitive: false,
    ).hasMatch(name)) {
      return null;
    }
    return UpdateReadinessSignal._(candidate);
  }

  Future<void> write({
    UpdateReadinessSignalWriter writer = const IoUpdateReadinessSignalWriter(),
  }) => writer.write(path);
}
