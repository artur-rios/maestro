import 'package:maestro/platform/common/command_runner.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    throw ArgumentError('dart executable, worker script, and marker required');
  }
  await const IoDetachedProcessLauncher().launch(
    CommandRequest(
      executable: arguments[0],
      arguments: <String>[arguments[1], arguments[2]],
    ),
  );
}
