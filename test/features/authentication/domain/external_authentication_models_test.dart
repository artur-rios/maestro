import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

void main() {
  test(
    'GivenGeneratedRecoveryCode_WhenPersisted_ThenDigestDoesNotContainPlaintext',
    () {
      final code = RecoveryCode.generate(Random(7));

      expect(
        code.display,
        matches(RegExp(r'^[A-Z0-9]{4}(-[A-Z0-9]{4}){5}-[A-Z0-9]{2}$')),
      );
      expect(code.digest, hasLength(64));
      expect(code.digest, isNot(contains(code.display)));
    },
  );

  test('GivenDisplayedRecoveryCode_WhenParsed_ThenInputIsNormalized', () {
    final parsed = RecoveryCode.parse('abcd-efgh-jkmn-pqrs-tvwx-yz01-20');

    expect(parsed.display, 'ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-20');
    expect(parsed.digest, RecoveryCode.parse(parsed.display).digest);
  });

  test('GivenKnownRecoveryCode_WhenParsed_ThenDigestIsCanonicalSha256', () {
    final code = RecoveryCode.parse('ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-20');

    expect(
      code.digest,
      '49c2d55bd9b79b04456d1d6718be8fdd5c0e9121243f07d58dcb4b820d0eab81',
    );
  });

  test('GivenMisplacedWhitespaceOrHyphens_WhenParsed_ThenItThrows', () {
    for (final input in <String>[
      ' ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-23',
      'ABCD-EFGH-JKMN-PQRS-TVWX-YZ0123',
      'ABCD-EFGH-JKMN-PQRS-TVWX-YZ01--23',
    ]) {
      expect(() => RecoveryCode.parse(input), throwsFormatException);
    }
  });

  test('GivenInvalidTailBits_WhenParsed_ThenItThrows', () {
    expect(
      () => RecoveryCode.parse('ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-2Z'),
      throwsFormatException,
    );
  });

  test('GivenAmbiguousRecoveryAlphabet_WhenParsed_ThenItThrows', () {
    for (final symbol in <String>['I', 'L', 'O', 'U']) {
      expect(
        () => RecoveryCode.parse(
          'ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-$symbol'
          '3',
        ),
        throwsFormatException,
      );
    }
  });

  test('GivenMalformedRecoveryCode_WhenParsed_ThenItThrows', () {
    for (final input in <String>[
      '',
      'ABCD-EFGH-JKMN-PQRS-TVWX',
      'ABCD-EFGH-JKMN-PQRS-TVWX-YZ0!',
      'ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-234',
    ]) {
      expect(() => RecoveryCode.parse(input), throwsFormatException);
    }
  });

  test('GivenRandomSource_WhenCodeSetCreated_ThenItContainsTenUniqueCodes', () {
    final set = NewRecoveryCodeSet.generate(Random(11));

    expect(set.codes, hasLength(RecoveryCode.count));
    expect(
      set.codes.map((code) => code.display).toSet(),
      hasLength(RecoveryCode.count),
    );
  });

  test('GivenInvalidScope_WhenConfigurationCreated_ThenItThrows', () {
    expect(
      () => ExternalAuthenticationConfiguration(
        clientId: 'desktop-client',
        scopeId: 'bad',
      ),
      throwsFormatException,
    );
  });

  test('GivenValidConfiguration_WhenCreated_ThenValuesAreRetained', () {
    final config = ExternalAuthenticationConfiguration(
      clientId: 'desktop-client',
      scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
    );
    expect(config.clientId, 'desktop-client');
    expect(config.scopeId, '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92');
  });

  test('GivenValidExternalIdentity_WhenCreated_ThenValuesAreRetained', () {
    final now = DateTime.utc(2026, 8, 18);
    final identity = ExternalAuthenticatedIdentity(
      subject: 'subject-1',
      email: 'person@example.com',
      token: 'token',
      expiresAt: now.add(const Duration(minutes: 5)),
      now: now,
      emailVerified: true,
    );

    expect(identity.subject, 'subject-1');
  });

  test('GivenInvalidExternalIdentity_WhenCreated_ThenItThrows', () {
    final now = DateTime.utc(2026, 8, 18);
    expect(
      () => ExternalAuthenticatedIdentity(
        subject: ' ',
        email: 'bad',
        token: '',
        expiresAt: now,
        now: now,
        emailVerified: false,
      ),
      throwsFormatException,
    );
  });
}
