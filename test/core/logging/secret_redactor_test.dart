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

  test(
    'GivenSecretShapedEnvironmentKeys_WhenRedacting_ThenTheirValuesAreHidden',
    () async {
      // Two hardcoded provider keys let a GITHUB_TOKEN an agent echoed reach
      // durable storage verbatim.
      const environment = <String, String>{
        'GITHUB_TOKEN': 'ghp_averylongtokenvalue',
        'OPENCODE_API_KEY': 'sk-anotherlongsecretvalue',
        'PATH': '/usr/bin:/bin',
        'TERM': 'xterm-256color',
      };

      final redacted = SecretRedactor().redact(
        'using ghp_averylongtokenvalue and sk-anotherlongsecretvalue '
        'on /usr/bin:/bin',
        environment: environment,
      );

      expect(redacted, isNot(contains('ghp_averylongtokenvalue')));
      expect(redacted, isNot(contains('sk-anotherlongsecretvalue')));
      // A PATH is not a secret, and blanking it would make output unreadable.
      expect(redacted, contains('/usr/bin:/bin'));
    },
  );

  test('GivenAPublicKeyVariable_WhenRedacting_ThenItIsNotTreatedAsSecret', () {
    expect(isSecretEnvironmentKey('MAESTRO_RELEASE_PUBLIC_KEY'), isFalse);
    expect(isSecretEnvironmentKey('ANTHROPIC_API_KEY'), isTrue);
    expect(isSecretEnvironmentKey('GH_TOKEN'), isTrue);
    expect(isSecretEnvironmentKey('TERM'), isFalse);
  });

  test('GivenAShortValue_WhenSelectingSecrets_ThenItIsIgnored', () {
    // A one- or two-character value is a flag far more often than a
    // credential, and blanking those would turn ordinary output into noise.
    expect(secretValuesIn(const <String, String>{'CI_TOKEN': '1'}), isEmpty);
  });
}
