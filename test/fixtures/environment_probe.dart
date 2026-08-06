import 'dart:io';

void main() {
  stdout.write(Platform.environment['MAESTRO_ALLOWED'] ?? '<missing>');
  stdout.write('|');
  stdout.write(
    Platform.environment.containsKey('USERNAME') ||
            Platform.environment.containsKey('USER')
        ? '<leaked>'
        : '<absent>',
  );
}
