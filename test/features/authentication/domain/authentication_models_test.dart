import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';

void main() {
  // FR-AU-02: email-account identifiers are normalized before use.
  test('GivenMixedCaseEmail_WhenParsed_ThenCanonicalValueIsLowercase', () {
    expect(
      NormalizedEmail.parse(' User@Example.COM ').value,
      'user@example.com',
    );
  });

  // FR-AU-03 and FR-AU-04: reject underlength passwords with guidance.
  test(
    'GivenShortPassword_WhenValidated_ThenMinimumAndGuidanceAreReturned',
    () {
      expect(
        () => LocalPassword.validate('short'),
        throwsA(
          isA<PasswordTooShort>()
              .having((failure) => failure.minimumLength, 'minimum length', 8)
              .having((failure) => failure.guidance, 'guidance', isNotEmpty),
        ),
      );
    },
  );

  // FR-AU-03: exactly eight characters is the accepted lower boundary.
  test('GivenEightCharacterPassword_WhenValidated_ThenValueIsReturned', () {
    expect(LocalPassword.validate('password').value, 'password');
  });

  // FR-AU-03: seven characters remains below the required boundary.
  test(
    'GivenSevenCharacterPassword_WhenValidated_ThenPasswordTooShortIsThrown',
    () {
      expect(
        () => LocalPassword.validate('passw0r'),
        throwsA(isA<PasswordTooShort>()),
      );
    },
  );

  // FR-AU-07 and BR-21: every authenticated local user has full control.
  test(
    'GivenAuthenticatedUser_WhenFullControlSessionIsCreated_ThenAllPermissionsAreGranted',
    () {
      const session = AuthenticatedSession.fullControl('user-1');

      expect(session.userId, 'user-1');
      expect(session.canManageRecords, isTrue);
      expect(session.canRunWorkflows, isTrue);
      expect(session.canDeliverChanges, isTrue);
    },
  );
}
