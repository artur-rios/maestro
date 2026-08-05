import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';

void main() {
  test('GivenMixedCaseEmail_WhenParsed_ThenCanonicalValueIsLowercase', () {
    expect(
      NormalizedEmail.parse(' User@Example.COM ').value,
      'user@example.com',
    );
  });

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
