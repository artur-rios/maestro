import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
import 'package:maestro/features/authentication/presentation/authentication_controller.dart';
import 'package:maestro/features/authentication/presentation/authentication_page.dart';

void main() {
  testWidgets('GivenSignedOut_WhenRendered_ThenProtectedShellIsHidden', (
    tester,
  ) async {
    var protectedBuilds = 0;

    await tester.pumpWidget(
      _testApp(
        _authenticationService(),
        authenticatedBuilder: (_) {
          protectedBuilds++;
          return const Text('Foundation ready');
        },
      ),
    );

    expect(find.text('Foundation ready'), findsNothing);
    expect(find.text('Sign in with your operating system'), findsOneWidget);
    expect(protectedBuilds, 0);
  });

  testWidgets(
    'GivenOperatingSystemApproval_WhenSelected_ThenProtectedShellIsVisible',
    (tester) async {
      await tester.pumpWidget(_testApp(_authenticationService()));

      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Foundation ready'), findsOneWidget);
      expect(find.bySemanticsLabel('Sign out'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenOperatingSystemDenial_WhenCompleted_ThenEmailPasswordFallbackIsVisible',
    (tester) async {
      final service = _authenticationService(
        operatingSystemResult: const FailureResult<void>(
          SecurityFailure(
            code: 'authentication.operating_system.denied',
            message: 'Operating-system authentication was denied.',
          ),
        ),
      );
      await tester.pumpWidget(_testApp(service));

      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Authentication was not successful.'), findsOneWidget);
      expect(find.bySemanticsLabel('Email address'), findsOneWidget);
      expect(find.bySemanticsLabel('Password'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Sign in with email and password'),
        findsOneWidget,
      );
      expect(find.text('Foundation ready'), findsNothing);
    },
  );

  testWidgets(
    'GivenAccountCreationMode_WhenOperatingSystemIsUnavailable_ThenDirectEmailSignInIsRestored',
    (tester) async {
      final service = _authenticationService(
        operatingSystemResult: const FailureResult<void>(
          PlatformFailure(
            code: 'authentication.operating_system.unavailable',
            message: 'Operating-system authentication is unavailable.',
          ),
        ),
      );
      await tester.pumpWidget(_testApp(service));
      await tester.tap(find.bySemanticsLabel('Create a local account'));
      await tester.pump();
      expect(find.bySemanticsLabel('Create account'), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Sign in with email and password'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Create account'), findsNothing);
      expect(find.text('Authentication was not successful.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenShortNewPassword_WhenSubmitted_ThenLengthAndStrengthGuidanceIsVisible',
    (tester) async {
      await tester.pumpWidget(_testApp(_authenticationService()));

      await tester.tap(find.bySemanticsLabel('Create a local account'));
      await tester.pump();
      await tester.enterText(
        find.bySemanticsLabel('Email address'),
        'new@example.com',
      );
      await tester.enterText(find.bySemanticsLabel('Password'), 'short');
      await tester.tap(find.bySemanticsLabel('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password must contain at least 8 characters.'),
        findsOneWidget,
      );
      expect(find.text('Choose a strong, unique password.'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        isEmpty,
      );
      expect(find.text('Foundation ready'), findsNothing);
    },
  );

  testWidgets(
    'GivenMalformedEmail_WhenCreatingAccount_ThenEmailGuidanceIsVisibleAndContentStaysProtected',
    (tester) async {
      await tester.pumpWidget(_testApp(_authenticationService()));
      await tester.tap(find.bySemanticsLabel('Create a local account'));
      await tester.pump();
      await tester.enterText(
        find.bySemanticsLabel('Email address'),
        'person@@example.com',
      );
      await tester.enterText(
        find.bySemanticsLabel('Password'),
        'strong-password',
      );

      await tester.tap(find.bySemanticsLabel('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Foundation ready'), findsNothing);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'GivenBlankEmail_WhenSigningIn_ThenEmailGuidanceIsVisibleAndContentStaysProtected',
    (tester) async {
      await tester.pumpWidget(_testApp(_authenticationService()));
      await tester.enterText(find.bySemanticsLabel('Email address'), '   ');
      await tester.enterText(
        find.bySemanticsLabel('Password'),
        'strong-password',
      );

      await tester.tap(
        find.bySemanticsLabel('Sign in with email and password'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Foundation ready'), findsNothing);
    },
  );

  testWidgets(
    'GivenExistingEmail_WhenAccountCreated_ThenCredentialNeutralErrorIsVisible',
    (tester) async {
      final users = _MemoryAuthenticationRepository()
        ..users.add(_passwordUser(email: 'person@example.com'));
      await tester.pumpWidget(_testApp(_authenticationService(users: users)));

      await tester.tap(find.bySemanticsLabel('Create a local account'));
      await tester.pump();
      await tester.enterText(
        find.bySemanticsLabel('Email address'),
        'PERSON@example.com',
      );
      await tester.enterText(
        find.bySemanticsLabel('Password'),
        'strong-password',
      );
      await tester.tap(find.bySemanticsLabel('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Account creation could not be completed.'),
        findsOneWidget,
      );
      expect(
        find.text('An account already exists for this email address.'),
        findsNothing,
      );
      expect(find.text('Foundation ready'), findsNothing);
    },
  );

  testWidgets(
    'GivenInvalidCredentials_WhenSigningIn_ThenCredentialNeutralErrorIsVisible',
    (tester) async {
      await tester.pumpWidget(_testApp(_authenticationService()));

      await tester.enterText(
        find.bySemanticsLabel('Email address'),
        'unknown@example.com',
      );
      await tester.enterText(
        find.bySemanticsLabel('Password'),
        'wrong-password',
      );
      await tester.tap(
        find.bySemanticsLabel('Sign in with email and password'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Authentication was not successful.'), findsOneWidget);
      expect(
        find.text('The email address or password is invalid.'),
        findsNothing,
      );
      expect(find.text('Foundation ready'), findsNothing);
    },
  );

  testWidgets('GivenAuthenticated_WhenSigningOut_ThenProtectedShellIsRemoved', (
    tester,
  ) async {
    final users = _MemoryAuthenticationRepository()
      ..users.add(_passwordUser(email: 'person@example.com'));
    await tester.pumpWidget(
      _testApp(
        _authenticationService(
          users: users,
          verifiers: _MemoryPasswordVerifierStore()
            ..values['verifier-person'] = 'strong-password',
        ),
      ),
    );
    await tester.enterText(
      find.bySemanticsLabel('Email address'),
      'person@example.com',
    );
    await tester.enterText(
      find.bySemanticsLabel('Password'),
      'strong-password',
    );
    await tester.tap(find.bySemanticsLabel('Sign in with email and password'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Foundation ready'), findsNothing);
    expect(find.text('Sign in with your operating system'), findsOneWidget);
  });

  testWidgets(
    'GivenValidAccountDetails_WhenCreated_ThenOneFullControlProtectedTransitionOccurs',
    (tester) async {
      final hashing = Completer<String>();
      final service = _authenticationService(
        hasher: _CompletingPasswordHasher(hashing),
      );
      var protectedBuilds = 0;
      await tester.pumpWidget(
        _testApp(
          service,
          authenticatedBuilder: (_) {
            protectedBuilds++;
            return const Text('Foundation ready');
          },
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuthenticationPage)),
      );
      await tester.tap(find.bySemanticsLabel('Create a local account'));
      await tester.pump();
      await tester.enterText(
        find.bySemanticsLabel('Email address'),
        'new@example.com',
      );
      await tester.enterText(
        find.bySemanticsLabel('Password'),
        'strong-password',
      );

      await tester.tap(find.bySemanticsLabel('Create account'));
      await tester.pump();

      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        isEmpty,
      );
      hashing.complete('hashed-verifier');
      await tester.pumpAndSettle();

      final state = container.read(authenticationControllerProvider);
      expect(state, isA<AuthenticationAuthenticated>());
      final session = (state as AuthenticationAuthenticated).session;
      expect(session.canManageRecords, isTrue);
      expect(session.canRunWorkflows, isTrue);
      expect(session.canDeliverChanges, isTrue);
      expect(protectedBuilds, 1);
      expect(find.text('Foundation ready'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenPendingAuthentication_WhenSignedOut_ThenLateSuccessNeverBuildsProtectedContent',
    (tester) async {
      final operatingSystem = _CompletingOperatingSystemAuthenticator();
      final service = _authenticationService(
        operatingSystemAuthentication: operatingSystem,
      );
      var protectedBuilds = 0;
      await tester.pumpWidget(
        _testApp(
          service,
          authenticatedBuilder: (_) {
            protectedBuilds++;
            return const Text('Foundation ready');
          },
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuthenticationPage)),
      );
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pump();

      container.read(authenticationControllerProvider.notifier).signOut();
      await tester.pump();
      operatingSystem.complete(const Success<void>(null));
      await tester.pumpAndSettle();

      expect(protectedBuilds, 0);
      expect(find.text('Foundation ready'), findsNothing);
      expect(find.text('Sign in with your operating system'), findsOneWidget);
      expect(service.currentSession, isNull);
    },
  );
}

Widget _testApp(
  AuthenticationService service, {
  WidgetBuilder? authenticatedBuilder,
}) {
  return ProviderScope(
    overrides: [authenticationServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      home: AuthenticationPage(
        authenticatedBuilder:
            authenticatedBuilder ?? (_) => const Text('Foundation ready'),
      ),
    ),
  );
}

AuthenticationService _authenticationService({
  _MemoryAuthenticationRepository? users,
  _MemoryPasswordVerifierStore? verifiers,
  PasswordHasher? hasher,
  OperatingSystemAuthenticator? operatingSystemAuthentication,
  Result<void> operatingSystemResult = const Success<void>(null),
}) {
  var nextId = 0;
  final repository = users ?? _MemoryAuthenticationRepository();
  return AuthenticationService(
    users: repository,
    verifiers: verifiers ?? _MemoryPasswordVerifierStore(),
    hasher: hasher ?? const _PlainPasswordHasher(),
    audits: repository,
    operatingSystemAuthentication:
        operatingSystemAuthentication ??
        _FakeOperatingSystemAuthenticator(operatingSystemResult),
    clock: () => DateTime.utc(2026, 8, 5),
    newId: () => 'id-${nextId++}',
  );
}

LocalUser _passwordUser({required String email}) {
  return LocalUser(
    id: 'person',
    email: NormalizedEmail.parse(email),
    authenticationMethod: AuthenticationMethod.emailPassword,
    verifierKey: 'verifier-person',
    createdAt: DateTime.utc(2026, 8, 5),
    lastAuthenticatedAt: null,
  );
}

final class _MemoryAuthenticationRepository
    implements LocalUserRepository, AuditRepository {
  final List<LocalUser> users = <LocalUser>[];
  final List<AuthenticationAuditEvent> events = <AuthenticationAuditEvent>[];

  @override
  Future<void> append(AuthenticationAuditEvent event) async =>
      events.add(event);

  @override
  Future<void> deleteEvent(String eventId) async {
    events.removeWhere((event) => event.id == eventId);
  }

  @override
  Future<void> delete(String userId) async {
    users.removeWhere((user) => user.id == userId);
  }

  @override
  Future<LocalUser?> findByEmail(NormalizedEmail email) async {
    for (final user in users) {
      if (user.email?.value == email.value) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<LocalUser?> findOperatingSystemUser() async {
    for (final user in users) {
      if (user.authenticationMethod == AuthenticationMethod.operatingSystem) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<void> save(LocalUser user) async => users.add(user);

  @override
  Future<void> updateLastAuthenticatedAt(String userId, DateTime value) async {}
}

final class _MemoryPasswordVerifierStore implements PasswordVerifierStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String verifier) async {
    values[key] = verifier;
  }
}

final class _PlainPasswordHasher implements PasswordHasher {
  const _PlainPasswordHasher();

  @override
  Future<String> create(String password) async => password;

  @override
  Future<bool> verify(String verifier, String password) async {
    return verifier == password;
  }
}

final class _CompletingPasswordHasher implements PasswordHasher {
  const _CompletingPasswordHasher(this.completion);

  final Completer<String> completion;

  @override
  Future<String> create(String password) => completion.future;

  @override
  Future<bool> verify(String verifier, String password) async => false;
}

final class _FakeOperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  const _FakeOperatingSystemAuthenticator(this.result);

  final Result<void> result;

  @override
  Future<Result<void>> authenticateCurrentUser() async => result;
}

final class _CompletingOperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  final Completer<Result<void>> _completion = Completer<Result<void>>();

  void complete(Result<void> result) => _completion.complete(result);

  @override
  Future<Result<void>> authenticateCurrentUser() => _completion.future;
}
