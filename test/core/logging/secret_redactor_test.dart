import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/logging/secret_redactor.dart';

void main() {
  group('SecretRedactor', () {
    test('GivenCredentials_WhenRedacting_ThenSecretsAreAbsent', () {
      final value = SecretRedactor().redact(
        'Authorization: Bearer abc password=hunter2 TOKEN=xyz',
        environment: const {'TOKEN': 'xyz'},
      );

      expect(value, isNot(contains('abc')));
      expect(value, isNot(contains('hunter2')));
      expect(value, isNot(contains('xyz')));
      expect(value, contains('Authorization: Bearer [REDACTED]'));
      expect(value, contains('password=[REDACTED]'));
      expect(value, contains('TOKEN=[REDACTED]'));
    });

    test('GivenEmptyEnvironmentValue_WhenRedacting_ThenTextIsPreserved', () {
      final value = SecretRedactor().redact(
        'ordinary output',
        environment: const {'OPTIONAL_TOKEN': ''},
      );

      expect(value, 'ordinary output');
    });
  });
}
