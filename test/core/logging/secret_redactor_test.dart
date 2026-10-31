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

  test('GivenCommonCredentialFormats_WhenRedacting_ThenNoneSurvive', () {
    // A prefixed key, a JSON field, GitHub's token scheme, and credentials
    // recognisable by shape all reached durable logs verbatim unless the
    // exact value also happened to be in Maestro's own environment.
    const secrets = <String>[
      'ghp_0123456789abcdefghijABCDEFGHIJ',
      'sk-ant-api03-0123456789abcdefghijkl',
      'sk-proj-0123456789abcdefghijklmn',
      'ya29.a0AfB_0123456789abcdefghij',
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.c2lnbmF0dXJlLXZhbHVl',
      'github_pat_11ABCDEFG0123456789_abcdefghij',
      'plain-db-password-1',
      'oauth-access-value',
    ];
    final input = <String>[
      'GITHUB_TOKEN=${secrets[0]}',
      'ANTHROPIC_API_KEY="${secrets[1]}"',
      'key: ${secrets[2]}',
      '{"access_token":"${secrets[3]}","id_token":"x"}',
      'Authorization: token ${secrets[4]}',
      '"Authorization": "Bearer ${secrets[5]}"',
      'DB_PASSWORD=${secrets[6]}',
      '{"refresh_token": "${secrets[7]}"}',
    ].join('\n');

    final redacted = SecretRedactor().redact(input);

    for (final secret in secrets) {
      expect(redacted, isNot(contains(secret)));
    }
    expect(redacted, contains('GITHUB_TOKEN=[REDACTED]'));
  });

  test('GivenOrdinaryOutput_WhenRedacting_ThenItIsUnchanged', () {
    const output =
        '"input_tokens":120 max_tokens: 4096 sk-learn tokenizer=fast '
        'see /home/user/project/token_store.dart';

    expect(SecretRedactor().redact(output), output);
  });

  test('GivenTheWorkingDirectory_WhenSelectingSecrets_ThenItIsNotOne', () {
    // PWD is the launch directory; blanking it mangled every path in output.
    expect(isSecretEnvironmentKey('PWD'), isFalse);
    expect(isSecretEnvironmentKey('OLDPWD'), isFalse);
    expect(isSecretEnvironmentKey('DB_PWD'), isTrue);
  });

  test(
    'GivenAnEnvironmentSecretHoldingADelimiter_WhenRedacting_ThenNoPartIsLeft',
    () {
      final redacted = SecretRedactor().redact(
        'password=p@ss;word99 done',
        environment: const <String, String>{'APP_PASSWORD': 'p@ss;word99'},
      );

      expect(redacted, isNot(contains('word99')));
      expect(redacted, contains('done'));
    },
  );
}
