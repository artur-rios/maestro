import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

void main() {
  test(
    'GivenGeneratedRecoveryCode_WhenPersisted_ThenDigestDoesNotContainPlaintext',
    () {
      final code = RecoveryCode.generate(Random(7));

      expect(code.display, matches(RegExp(r'^[A-Z0-9]{4}(-[A-Z0-9]{4}){4}$')));
      expect(code.digest, hasLength(64));
      expect(code.digest, isNot(contains(code.display)));
    },
  );

  test('GivenDisplayedRecoveryCode_WhenParsed_ThenInputIsNormalized', () {
    final parsed = RecoveryCode.parse('abcd-efgh-jkmn-pqrs-tvwx');

    expect(parsed.display, 'ABCD-EFGH-JKMN-PQRS-TVWX');
    expect(parsed.digest, RecoveryCode.parse(parsed.display).digest);
  });

  test('GivenMalformedRecoveryCode_WhenParsed_ThenItThrows', () {
    for (final input in <String>[
      '',
      'ABCD-EFGH',
      'ABCD-EFGH-I L M N-PQRS-TUVW',
      'ABCD-EFGH-IJKL-PQRS-TUV!',
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
}
