import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

void main() {
  late _FakeLocalUserRepository users;
  late _FakePasswordVerifierStore verifiers;
  late _FakePasswordHasher hasher;
  late _FakeAuditRepository audits;
  late _FakeOperatingSystemAuthenticator operatingSystemAuthentication;
  late _FakeRecoveryCodeRepository recoveryCodes;
  late _FakeAuthenticationSettingsRepository settings;
  late _FakeGoogleBrowserAuthorization googleAuthorization;
  late _FakeExternalAuthenticationGateway externalGateway;
  late _FakeSessionExpiryScheduler expiryScheduler;
  late DateTime now;
  late AuthenticationService service;

  setUp(() {
    users = _FakeLocalUserRepository();
    verifiers = _FakePasswordVerifierStore();
    hasher = _FakePasswordHasher();
    audits = _FakeAuditRepository();
    operatingSystemAuthentication = _FakeOperatingSystemAuthenticator();
    recoveryCodes = _FakeRecoveryCodeRepository();
    settings = _FakeAuthenticationSettingsRepository();
    googleAuthorization = _FakeGoogleBrowserAuthorization();
    externalGateway = _FakeExternalAuthenticationGateway();
    expiryScheduler = _FakeSessionExpiryScheduler();
    now = DateTime.utc(2026, 8, 5, 12);
    service = AuthenticationService(
      users: users,
      verifiers: verifiers,
      hasher: hasher,
      audits: audits,
      operatingSystemAuthentication: operatingSystemAuthentication,
      recoveryCodes: recoveryCodes,
      settings: settings,
      googleAuthorization: googleAuthorization,
      externalGateway: externalGateway,
      newRecoveryCodeSet: () => NewRecoveryCodeSet.generate(Random(7)),
      scheduleExpiry: expiryScheduler.schedule,
      clock: () => now,
      newId: _DeterministicIds().next,
    );
  });

  // FR-AU-02 and FR-AU-05: normalized account creation stores a verifier only.
  test(
    'GivenNewEmailAccount_WhenCreated_ThenFullControlSessionIsOpened',
    () async {
      final result = await service.createAccount(
        ' User@Example.com ',
        'password1',
      );

      expect(result, isA<Success<LocalAccountCreation>>());
      expect(users.saved, hasLength(1));
      expect(users.saved.single.email!.value, 'user@example.com');
      expect(verifiers.writes.keys, contains('maestro.auth.verifier.user-1'));
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.success);
      expect(service.currentSession, isNull);
    },
  );

  // FR-AU-02: normalized duplicates cannot mutate credentials or user storage.
  test(
    'GivenDuplicateNormalizedEmail_WhenCreating_ThenNothingIsStored',
    () async {
      users.existingEmail = 'user@example.com';

      final result = await service.createAccount(
        ' User@Example.com ',
        'password1',
      );

      expect(result, isA<FailureResult<LocalAccountCreation>>());
      expect(verifiers.writes, isEmpty);
      expect(users.saved, isEmpty);
      expect(audits.events, isEmpty);
    },
  );

  // FR-AU-03 and FR-AU-04: short passwords fail with no persistence.
  test(
    'GivenShortPassword_WhenCreating_ThenValidationFailureLeavesStorageUntouched',
    () async {
      final result = await service.createAccount('user@example.com', 'short');

      expect(result, isA<FailureResult<LocalAccountCreation>>());
      expect(
        (result as FailureResult<LocalAccountCreation>).failure,
        isA<ValidationFailure>(),
      );
      expect(verifiers.writes, isEmpty);
      expect(users.saved, isEmpty);
    },
  );

  test(
    'GivenInvalidEmail_WhenCreating_ThenTypedFailurePrecedesEveryMutation',
    () async {
      for (final email in <String>[
        '',
        '   ',
        'invalid',
        'person@@example.com',
      ]) {
        final result = await service.createAccount(email, 'strong-password');

        expect(
          result,
          isA<FailureResult<LocalAccountCreation>>(),
          reason: email,
        );
        final failure = (result as FailureResult<LocalAccountCreation>).failure;
        expect(failure, isA<ValidationFailure>(), reason: email);
        expect(failure.code, 'authentication.email.invalid', reason: email);
      }
      expect(users.findEmailInputs, isEmpty);
      expect(hasher.createInputs, isEmpty);
      expect(verifiers.writes, isEmpty);
      expect(users.saved, isEmpty);
      expect(audits.events, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenMalformedEmail_WhenSigningIn_ThenStorageAndAuditAreNotAccessed',
    () async {
      final result = await service.signInWithEmail(
        'person@example..com',
        'strong-password',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      final failure = (result as FailureResult<AuthenticatedSession>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'authentication.email.invalid');
      expect(users.findEmailInputs, isEmpty);
      expect(verifiers.readKeys, isEmpty);
      expect(users.lastAuthenticatedUserIds, isEmpty);
      expect(audits.events, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  // FR-AU-05: persistence failure compensates the newly stored verifier.
  test('GivenUserSaveFailure_WhenCreating_ThenNewVerifierIsRemoved', () async {
    users.failWhenSaving = true;

    final result = await service.createAccount('user@example.com', 'password1');

    expect(result, isA<FailureResult<LocalAccountCreation>>());
    expect(verifiers.deleted, <String>['maestro.auth.verifier.user-1']);
    expect(service.currentSession, isNull);
  });

  // FR-AU-02 and FR-AU-05: an audit failure leaves no duplicate account state.
  test(
    'GivenAuditFailure_WhenCreating_ThenAccountIsCompensatedAndCanRetry',
    () async {
      audits.failWhenAppending = true;

      final failed = await service.createAccount(
        'user@example.com',
        'password1',
      );

      expect(failed, isA<FailureResult<LocalAccountCreation>>());
      expect(users.deletedUserIds, <String>['user-1']);
      expect(verifiers.deleted, <String>['maestro.auth.verifier.user-1']);
      expect(service.currentSession, isNull);

      audits.failWhenAppending = false;
      final retried = await service.createAccount(
        'user@example.com',
        'password1',
      );

      expect(retried, isA<Success<LocalAccountCreation>>());
    },
  );

  // FR-AU-05: a failed credential cleanup is surfaced as a typed failure.
  test(
    'GivenVerifierRollbackFailure_WhenCreating_ThenCleanupFailureIsReturned',
    () async {
      users.failWhenSaving = true;
      verifiers.failWhenDeleting = true;

      final result = await service.createAccount(
        'user@example.com',
        'password1',
      );

      expect(result, isA<FailureResult<LocalAccountCreation>>());
      final failure = (result as FailureResult<LocalAccountCreation>).failure;
      expect(failure.code, 'authentication.verifier.cleanup.failed');
      expect(failure.cause, isNull);
      expect(failure.message, isNot(contains('password1')));
      expect(failure.message, isNot(contains('maestro.auth.verifier.user-1')));
    },
  );

  test(
    'GivenVerifierWriteCompletesAfterSignOut_WhenCreating_ThenVerifierIsRolledBack',
    () async {
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      verifiers.afterWrite = (_, _) {
        writeStarted.complete();
        return releaseWrite.future;
      };
      final pending = service.createAccount('user@example.com', 'password1');
      await writeStarted.future;

      service.signOut();
      releaseWrite.complete();
      final result = await pending;

      expect(result, isA<FailureResult<LocalAccountCreation>>());
      expect(
        (result as FailureResult<LocalAccountCreation>).failure.code,
        'authentication.operation.stale',
      );
      expect(verifiers.values, isEmpty);
      expect(
        await users.findByEmail(NormalizedEmail.parse('user@example.com')),
        isNull,
      );
      expect(audits.events, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenUserSaveCompletesAfterSignOut_WhenCreating_ThenUserAndVerifierAreRolledBack',
    () async {
      final saveStarted = Completer<void>();
      final releaseSave = Completer<void>();
      users.afterSave = (_) {
        saveStarted.complete();
        return releaseSave.future;
      };
      final pending = service.createAccount('user@example.com', 'password1');
      await saveStarted.future;

      service.signOut();
      releaseSave.complete();
      final result = await pending;

      expect(result, isA<FailureResult<LocalAccountCreation>>());
      expect(
        (result as FailureResult<LocalAccountCreation>).failure.code,
        'authentication.operation.stale',
      );
      expect(verifiers.values, isEmpty);
      expect(
        await users.findByEmail(NormalizedEmail.parse('user@example.com')),
        isNull,
      );
      expect(audits.events, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenAuditAppendCompletesAfterSignOut_WhenCreating_ThenAllAccountStateIsRolledBack',
    () async {
      final appendStarted = Completer<void>();
      final releaseAppend = Completer<void>();
      audits.afterAppend = (_) {
        appendStarted.complete();
        return releaseAppend.future;
      };
      final pending = service.createAccount('user@example.com', 'password1');
      await appendStarted.future;

      service.signOut();
      releaseAppend.complete();
      final result = await pending;

      expect(result, isA<FailureResult<LocalAccountCreation>>());
      expect(
        (result as FailureResult<LocalAccountCreation>).failure.code,
        'authentication.operation.stale',
      );
      expect(audits.events, isEmpty);
      expect(
        await users.findByEmail(NormalizedEmail.parse('user@example.com')),
        isNull,
      );
      expect(verifiers.values, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenStaleUserSaveAndUserCleanupFailure_WhenCreating_ThenVerifierCleanupStillRuns',
    () async {
      final saveStarted = Completer<void>();
      final releaseSave = Completer<void>();
      users.afterSave = (_) {
        saveStarted.complete();
        return releaseSave.future;
      };
      users.failWhenDeleting = true;
      final pending = service.createAccount('user@example.com', 'password1');
      await saveStarted.future;

      service.signOut();
      releaseSave.complete();
      final result = await pending;

      expect(result, isA<FailureResult<LocalAccountCreation>>());
      final failure = (result as FailureResult<LocalAccountCreation>).failure;
      expect(failure.code, 'authentication.account.cleanup.failed');
      expect(failure.cause, isNull);
      expect(verifiers.values, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenStaleAuditAndAuditCleanupFailure_WhenCreating_ThenCredentialsStillRollBack',
    () async {
      final appendStarted = Completer<void>();
      final releaseAppend = Completer<void>();
      audits.afterAppend = (_) {
        appendStarted.complete();
        return releaseAppend.future;
      };
      audits.failWhenDeleting = true;
      final pending = service.createAccount('user@example.com', 'password1');
      await appendStarted.future;

      service.signOut();
      releaseAppend.complete();
      final result = await pending;

      expect(result, isA<FailureResult<LocalAccountCreation>>());
      final failure = (result as FailureResult<LocalAccountCreation>).failure;
      expect(failure.code, 'authentication.audit.cleanup.failed');
      expect(failure.cause, isNull);
      expect(audits.events, hasLength(1));
      expect(
        await users.findByEmail(NormalizedEmail.parse('user@example.com')),
        isNull,
      );
      expect(verifiers.values, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  // FR-AU-02, FR-AU-05, and FR-AU-07: valid local credentials open full control.
  test(
    'GivenValidCredentials_WhenSigningInWithEmail_ThenFullControlSessionIsOpened',
    () async {
      users.existingEmail = 'user@example.com';
      verifiers.values['verifier-user-1'] = 'hashed:password1';

      final result = await service.signInWithEmail(
        ' USER@example.com ',
        'password1',
      );

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(users.lastAuthenticatedUserIds, <String>['user-1']);
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.success);
      expect(service.currentSession?.userId, 'user-1');
    },
  );

  // AF-04: invalid credentials remain signed out and write redacted evidence.
  test(
    'GivenInvalidCredentials_WhenSigningInWithEmail_ThenFailureIsAuditedWithoutCredentials',
    () async {
      users.existingEmail = 'user@example.com';
      verifiers.values['verifier-user-1'] = 'hashed:password1';

      final result = await service.signInWithEmail('user@example.com', 'wrong');

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.failure);
      expect(
        audits.events.single.details,
        '{"principal":"known","source":"local_password"}',
      );
      expect(audits.events.single.details, isNot(contains('user@example.com')));
      expect(audits.events.single.details, isNot(contains('wrong')));
      expect(service.currentSession, isNull);
    },
  );

  // AF-04: an unknown principal gets only the required redacted marker.
  test(
    'GivenUnknownEmail_WhenSigningIn_ThenUnknownPrincipalFailureIsAudited',
    () async {
      final result = await service.signInWithEmail(
        'unknown@example.com',
        'wrong',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        audits.events.single.details,
        '{"principal":"unknown","source":"local_password"}',
      );
      expect(service.currentSession, isNull);
    },
  );

  // AF-04: absent protected verifier material is never treated as success.
  test(
    'GivenMissingVerifier_WhenSigningIn_ThenCredentialsAreRejected',
    () async {
      users.existingEmail = 'user@example.com';

      final result = await service.signInWithEmail(
        'user@example.com',
        'password1',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.failure);
    },
  );

  // FR-AU-01 and AF-01: OS denial preserves the signed-out fallback state.
  test(
    'GivenOperatingSystemFailure_WhenSigningIn_ThenFallbackFailureLeavesSessionSignedOut',
    () async {
      operatingSystemAuthentication.result = const FailureResult<void>(
        PlatformFailure(code: 'authentication.denied', message: 'Denied.'),
      );

      final result = await service.signInWithOperatingSystem();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(service.currentSession, isNull);
      expect(users.saved, isEmpty);
    },
  );

  // FR-AU-01 and AF-01: thrown adapter failures are typed Results, not throws.
  test(
    'GivenThrownOperatingSystemAdapter_WhenSigningIn_ThenPlatformFailureIsReturned',
    () async {
      operatingSystemAuthentication.exception = StateError('native failed');

      final result = await service.signInWithOperatingSystem();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure,
        isA<PlatformFailure>(),
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenOperatingSystemSuccess_WhenSigningIn_ThenLocalSessionIsOpened',
    () async {
      final result = await service.signInWithOperatingSystem();

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(
        users.saved.single.authenticationMethod,
        AuthenticationMethod.operatingSystem,
      );
      expect(users.saved.single.email, isNull);
      expect(service.currentSession?.userId, 'user-1');
    },
  );

  // FR-AU-01: an existing OS user is updated instead of duplicated.
  test(
    'GivenExistingOperatingSystemUser_WhenSigningIn_ThenLastAuthenticatedAtIsUpdated',
    () async {
      users.operatingSystemUser = _operatingSystemUser();

      final result = await service.signInWithOperatingSystem();

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(users.saved, isEmpty);
      expect(users.lastAuthenticatedUserIds, <String>['os-user-1']);
    },
  );

  // FR-AU-06: sign-out returns the application to its unauthenticated state.
  test(
    'GivenAuthenticatedSession_WhenSigningOut_ThenOnlyInMemorySessionIsCleared',
    () async {
      await service.signInWithOperatingSystem();

      service.signOut();

      expect(service.currentSession, isNull);
      expect(users.saved, hasLength(1));
    },
  );

  test(
    'GivenPendingOperatingSystemAuthentication_WhenSignedOut_ThenLateSuccessCannotRestoreSession',
    () async {
      final completion = Completer<Result<void>>();
      operatingSystemAuthentication.authenticate = () => completion.future;
      final pending = service.signInWithOperatingSystem();

      service.signOut();
      completion.complete(const Success<void>(null));
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenOlderOperatingSystemAuthentication_WhenNewerEmailSignInSucceeds_ThenLateCompletionCannotReplaceSession',
    () async {
      users.existingEmail = 'person@example.com';
      users.operatingSystemUser = _operatingSystemUser();
      verifiers.values['verifier-user-1'] = 'hashed:password1';
      final completion = Completer<Result<void>>();
      operatingSystemAuthentication.authenticate = () => completion.future;
      final older = service.signInWithOperatingSystem();

      final newer = await service.signInWithEmail(
        'person@example.com',
        'password1',
      );
      completion.complete(const Success<void>(null));
      final olderResult = await older;

      expect(newer, isA<Success<AuthenticatedSession>>());
      expect(service.currentSession?.userId, 'user-1');
      expect(olderResult, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (olderResult as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
    },
  );

  test(
    'GivenPendingOperatingSystemAuthentication_WhenServiceIsDisposed_ThenLateSuccessCannotRestoreSession',
    () async {
      final completion = Completer<Result<void>>();
      operatingSystemAuthentication.authenticate = () => completion.future;
      final pending = service.signInWithOperatingSystem();

      service.dispose();
      completion.complete(const Success<void>(null));
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenPendingOperatingSystemAuthentication_WhenSignedOutAndAdapterFailsLate_ThenStaleFailureHasNoCause',
    () async {
      final completion = Completer<Result<void>>();
      operatingSystemAuthentication.authenticate = () => completion.future;
      final pending = service.signInWithOperatingSystem();

      service.signOut();
      completion.completeError(StateError('sentinel-late-native-detail'));
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      final failure = (result as FailureResult<AuthenticatedSession>).failure;
      expect(failure.code, 'authentication.operation.stale');
      expect(failure.cause, isNull);
      expect(failure.message, isNot(contains('sentinel-late-native-detail')));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenPendingEmailLookup_WhenServiceIsDisposed_ThenLaterCredentialStorageIsNotAccessed',
    () async {
      final lookup = Completer<LocalUser?>();
      users.findEmail = (_) => lookup.future;
      final pending = service.signInWithEmail(
        'person@example.com',
        'password1',
      );

      service.dispose();
      lookup.complete(_emailUser());
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
      expect(verifiers.readKeys, isEmpty);
      expect(users.lastAuthenticatedUserIds, isEmpty);
      expect(audits.events, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenNewLocalAccount_WhenCreated_ThenCodesArePersistedAndSessionWaitsForAcknowledgement',
    () async {
      final result = await service.createAccount(
        'person@example.com',
        'strong-password',
      );

      expect(result, isA<Success<LocalAccountCreation>>());
      final creation = (result as Success<LocalAccountCreation>).value;
      expect(creation.recoveryCodes.codes, hasLength(RecoveryCode.count));
      expect(recoveryCodes.saved, hasLength(RecoveryCode.count));
      expect(
        recoveryCodes.saved.map((code) => code.digest),
        unorderedEquals(
          creation.recoveryCodes.codes.map((code) => code.digest),
        ),
      );
      expect(
        recoveryCodes.saved.join(),
        isNot(contains(creation.recoveryCodes.codes.first.display)),
      );
      expect(creation.session.isActive, isFalse);
      expect(service.currentSession, isNull);

      final acknowledged = service.acknowledgeRecoveryCodes();

      expect(acknowledged, isA<Success<AuthenticatedSession>>());
      expect(creation.session.isActive, isTrue);
      expect(service.currentSession?.userId, creation.session.userId);
      expect(
        service.currentSession?.source,
        AuthenticationSource.localPassword,
      );
    },
  );

  test(
    'GivenRecoveryCodesAlreadyAcknowledged_WhenAcknowledgingAgain_ThenNoSessionIsRepublished',
    () async {
      await service.createAccount('person@example.com', 'strong-password');
      service.acknowledgeRecoveryCodes();
      service.signOut();

      final result = service.acknowledgeRecoveryCodes();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenRecoveryCodePersistenceFailure_WhenCreating_ThenAccountAndVerifierAreCompensated',
    () async {
      recoveryCodes.failWhenSaving = true;

      final result = await service.createAccount(
        'person@example.com',
        'strong-password',
      );

      expect(result, isA<FailureResult<LocalAccountCreation>>());
      expect(users.deletedUserIds, <String>['user-1']);
      expect(verifiers.values, isEmpty);
      expect(audits.events, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenEmailAccountAndVerifiedWindowsCredentials_WhenSigningIn_ThenItOpensThatEmailSession',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();

      final result = await service.signInWithLocalWindowsCredentials(
        'person@example.com',
      );

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(
        (result as Success<AuthenticatedSession>).value.userId,
        'email-user-1',
      );
      expect(service.currentSession?.source, AuthenticationSource.localWindows);
      expect(verifiers.readKeys, isEmpty);
      expect(operatingSystemAuthentication.attempts, 1);
    },
  );

  test(
    'GivenUnknownEmail_WhenSigningInWithWindows_ThenNativePromptIsNotOpenedAndFailureIsRedacted',
    () async {
      final result = await service.signInWithLocalWindowsCredentials(
        'missing@example.com',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(operatingSystemAuthentication.attempts, 0);
      expect(audits.events.single.details, contains('"principal":"unknown"'));
      expect(
        audits.events.single.details,
        isNot(contains('missing@example.com')),
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenPendingWindowsCredentialPrompt_WhenSignedOut_ThenLateSuccessCannotOpenSession',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      final completion = Completer<Result<void>>();
      operatingSystemAuthentication.authenticate = () => completion.future;
      final pending = service.signInWithLocalWindowsCredentials(
        'person@example.com',
      );
      await Future<void>.delayed(Duration.zero);

      service.signOut();
      completion.complete(const Success<void>(null));
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenWindowsAdapterAndFailureAuditThrow_WhenSigningInToEmailAccount_ThenTypedPlatformFailureIsReturned',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      operatingSystemAuthentication.exception = StateError('native detail');
      audits.failWhenAppending = true;

      final result = await service.signInWithLocalWindowsCredentials(
        'person@example.com',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      final failure = (result as FailureResult<AuthenticatedSession>).failure;
      expect(failure, isA<PlatformFailure>());
      expect(failure.cause, isNull);
      expect(failure.message, isNot(contains('native detail')));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenWindowsCredentialDenial_WhenSigningInToEmailAccount_ThenCredentialsAreRejected',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      operatingSystemAuthentication.result = const FailureResult<void>(
        PlatformFailure(code: 'authentication.denied', message: 'Denied.'),
      );

      final result = await service.signInWithLocalWindowsCredentials(
        'person@example.com',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.credentials.invalid',
      );
      expect(audits.events.single.details, contains('"principal":"known"'));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenWindowsCredentialAdapterUnavailable_WhenSigningInToEmailAccount_ThenRedactedPlatformFailureIsReturned',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      operatingSystemAuthentication.exception = StateError('native sentinel');

      final result = await service.signInWithLocalWindowsCredentials(
        'person@example.com',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      final failure = (result as FailureResult<AuthenticatedSession>).failure;
      expect(failure.code, 'authentication.operating_system.failed');
      expect(failure.cause, isNull);
      expect(failure.message, isNot(contains('native sentinel')));
      expect(audits.events.single.details, isNot(contains('native sentinel')));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenNonPasswordAccount_WhenUsingWindowsCredentialsByEmail_ThenItIsRejectedWithoutNativePrompt',
    () async {
      users.emailUsers['person@example.com'] = LocalUser(
        id: 'wrong-method-user',
        email: NormalizedEmail.parse('person@example.com'),
        authenticationMethod: AuthenticationMethod.operatingSystem,
        verifierKey: null,
        createdAt: now,
        lastAuthenticatedAt: null,
      );

      final result = await service.signInWithLocalWindowsCredentials(
        'person@example.com',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(operatingSystemAuthentication.attempts, 0);
      expect(audits.events.single.details, contains('"principal":"known"'));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenValidGoogleGrant_WhenSigningIn_ThenJwtSubjectOwnsExpiringExternalSession',
    () async {
      externalGateway.grant = ExternalTokenGrant(
        token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
        expiresAt: now.add(const Duration(minutes: 30)),
        emailVerified: true,
      );

      final result = await service.signInWithGoogle();

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(service.currentSession?.userId, 'external-actor');
      expect(service.currentSession?.source, AuthenticationSource.google);
      expect(service.currentSession?.remoteToken, externalGateway.grant.token);
      expect(
        service.currentSession?.remoteTokenExpiresAt,
        externalGateway.grant.expiresAt,
      );

      now = externalGateway.grant.expiresAt;
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenGoogleGrantExpiresDuringSuccessAudit_WhenPublishing_ThenExpiredSessionIsRejected',
    () async {
      final auditStarted = Completer<void>();
      final releaseAudit = Completer<void>();
      audits.afterAppend = (event) {
        if (event.outcome == AuthenticationAuditOutcome.success) {
          auditStarted.complete();
          return releaseAudit.future;
        }
        return Future<void>.value();
      };
      externalGateway.grant = ExternalTokenGrant(
        token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
        expiresAt: now.add(const Duration(minutes: 1)),
        emailVerified: true,
      );
      final pending = service.signInWithGoogle();
      await auditStarted.future;

      now = externalGateway.grant.expiresAt;
      releaseAudit.complete();
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.google.identity.invalid',
      );
      expect(service.currentSession, isNull);
      expect(expiryScheduler.pendingCallbacks, isEmpty);
    },
  );

  test(
    'GivenExpiredGoogleAuditCleanupIsSuperseded_WhenCleanupFinishes_ThenStaleOperationAddsNoFailureAudit',
    () async {
      final auditStarted = Completer<void>();
      final releaseAudit = Completer<void>();
      audits.afterAppend = (event) {
        if (event.details.contains('"source":"google"') &&
            event.outcome == AuthenticationAuditOutcome.success) {
          auditStarted.complete();
          return releaseAudit.future;
        }
        return Future<void>.value();
      };
      final deleteStarted = Completer<void>();
      final releaseDelete = Completer<void>();
      audits.afterDelete = (_) {
        deleteStarted.complete();
        return releaseDelete.future;
      };
      externalGateway.grant = ExternalTokenGrant(
        token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
        expiresAt: now.add(const Duration(minutes: 1)),
        emailVerified: true,
      );
      final older = service.signInWithGoogle();
      await auditStarted.future;
      now = externalGateway.grant.expiresAt;
      releaseAudit.complete();
      await deleteStarted.future;

      users.emailUsers['person@example.com'] = _emailUser();
      verifiers.values['verifier-email-user-1'] = 'hashed:password1';
      final newer = await service.signInWithEmail(
        'person@example.com',
        'password1',
      );
      releaseDelete.complete();
      final olderResult = await older;

      expect(newer, isA<Success<AuthenticatedSession>>());
      expect(olderResult, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (olderResult as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
      expect(audits.events, hasLength(1));
      expect(
        audits.events.single.details,
        contains('"source":"local_password"'),
      );
      expect(service.currentSession?.userId, 'email-user-1');
    },
  );

  test(
    'GivenPublishedGoogleSession_WhenExpiryArrives_ThenItIsRevokedClearedAndNotified',
    () async {
      externalGateway.grant = ExternalTokenGrant(
        token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
        expiresAt: now.add(const Duration(minutes: 30)),
        emailVerified: true,
      );
      final changes = <AuthenticatedSession?>[];
      final subscription = service.sessionChanges.listen(changes.add);
      addTearDown(subscription.cancel);
      final result = await service.signInWithGoogle();
      final retained = (result as Success<AuthenticatedSession>).value;

      now = externalGateway.grant.expiresAt;
      expiryScheduler.fireNext();

      expect(service.currentSession, isNull);
      expect(retained.isActive, isFalse);
      expect(retained.remoteToken, isNull);
      expect(retained.canManageRecords, isFalse);
      expect(changes, <AuthenticatedSession?>[retained, null]);
    },
  );

  test(
    'GivenPublishedGoogleSession_WhenSigningOut_ThenRetainedTokenAuthorityIsRevoked',
    () async {
      externalGateway.grant = ExternalTokenGrant(
        token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
        expiresAt: now.add(const Duration(minutes: 30)),
        emailVerified: true,
      );
      final changes = <AuthenticatedSession?>[];
      final subscription = service.sessionChanges.listen(changes.add);
      addTearDown(subscription.cancel);
      final result = await service.signInWithGoogle();
      final retained = (result as Success<AuthenticatedSession>).value;

      service.signOut();

      expect(retained.isActive, isFalse);
      expect(retained.remoteToken, isNull);
      expect(retained.canManageRecords, isFalse);
      expect(service.currentSession, isNull);
      expect(expiryScheduler.pendingCallbacks, isEmpty);
      expect(changes, <AuthenticatedSession?>[retained, null]);
    },
  );

  test(
    'GivenMalformedJwtPayload_WhenSigningInWithGoogle_ThenIdentityIsRejected',
    () async {
      externalGateway.grant = ExternalTokenGrant(
        token: 'header.%%%malformed%%%.signature',
        expiresAt: now.add(const Duration(minutes: 30)),
        emailVerified: true,
      );

      final result = await service.signInWithGoogle();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.google.identity.invalid',
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenUnverifiedGoogleGrant_WhenSigningIn_ThenIdentityIsRejected',
    () async {
      externalGateway.grant = ExternalTokenGrant(
        token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
        expiresAt: now.add(const Duration(minutes: 30)),
        emailVerified: false,
      );

      final result = await service.signInWithGoogle();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(service.currentSession, isNull);
      expect(expiryScheduler.pendingCallbacks, isEmpty);
    },
  );

  test(
    'GivenAlreadyExpiredGoogleGrant_WhenSigningIn_ThenIdentityIsRejected',
    () async {
      externalGateway.grant = ExternalTokenGrant(
        token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
        expiresAt: now,
        emailVerified: true,
      );

      final result = await service.signInWithGoogle();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(service.currentSession, isNull);
      expect(expiryScheduler.pendingCallbacks, isEmpty);
    },
  );

  test(
    'GivenGoogleGatewayFailure_WhenSigningIn_ThenFailureIsRedactedAndAudited',
    () async {
      externalGateway.exception = StateError('bearer sentinel');

      final result = await service.signInWithGoogle();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      final failure = (result as FailureResult<AuthenticatedSession>).failure;
      expect(failure.code, 'authentication.google.failed');
      expect(failure.cause, isNull);
      expect(failure.message, isNot(contains('bearer sentinel')));
      expect(audits.events.single.details, isNot(contains('bearer sentinel')));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenGoogleSuccessAuditFailure_WhenSigningIn_ThenTokenSessionIsNotPublished',
    () async {
      audits.failWhenAppending = true;
      externalGateway.grant = ExternalTokenGrant(
        token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
        expiresAt: now.add(const Duration(minutes: 30)),
        emailVerified: true,
      );

      final result = await service.signInWithGoogle();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.google.failed',
      );
      expect(service.currentSession, isNull);
      expect(expiryScheduler.pendingCallbacks, isEmpty);
    },
  );

  test(
    'GivenPendingGoogleGateway_WhenNewerLocalSignInSucceeds_ThenGoogleCannotReplaceSession',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      verifiers.values['verifier-email-user-1'] = 'hashed:password1';
      final grant = Completer<ExternalTokenGrant>();
      externalGateway.signInCallback =
          ({required String scopeId, required String idToken}) => grant.future;
      final older = service.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      final newer = await service.signInWithEmail(
        'person@example.com',
        'password1',
      );
      grant.complete(
        ExternalTokenGrant(
          token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
          expiresAt: now.add(const Duration(minutes: 30)),
          emailVerified: true,
        ),
      );
      final olderResult = await older;

      expect(newer, isA<Success<AuthenticatedSession>>());
      expect(olderResult, isA<FailureResult<AuthenticatedSession>>());
      expect(service.currentSession?.userId, 'email-user-1');
      expect(expiryScheduler.pendingCallbacks, isEmpty);
    },
  );

  test(
    'GivenGoogleGrantWithoutSubject_WhenSigningIn_ThenItFailsWithoutLeakingToken',
    () async {
      externalGateway.grant = ExternalTokenGrant(
        token: _jwtWithPayload(<String, Object?>{
          'email': 'person@example.com',
        }),
        expiresAt: now.add(const Duration(minutes: 30)),
        emailVerified: true,
      );

      final result = await service.signInWithGoogle();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      final failure = (result as FailureResult<AuthenticatedSession>).failure;
      expect(failure.code, 'authentication.google.identity.invalid');
      expect(failure.cause, isNull);
      expect(failure.message, isNot(contains(externalGateway.grant.token)));
      expect(
        audits.events.single.details,
        isNot(contains(externalGateway.grant.token)),
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenPendingGoogleAuthorization_WhenSignedOut_ThenAuthorizationIsCancelledAndCannotOpenSession',
    () async {
      final completion = Completer<GoogleIdToken>();
      googleAuthorization.authorizeCallback = (_) => completion.future;
      final pending = service.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      service.signOut();
      completion.complete(const GoogleIdToken('late-id-token'));
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(googleAuthorization.cancelAttempts, greaterThanOrEqualTo(1));
      expect(externalGateway.idTokens, isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenUnusedRecoveryCode_WhenRecovering_ThenItConsumesCodeAndReplacesVerifier',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      final code = RecoveryCode.generate(Random(11));
      recoveryCodes.unusedDigests.add(code.digest);

      final result = await service.recoverLocalAccount(
        'person@example.com',
        code.display,
        'new-password',
      );

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(service.currentSession?.userId, 'email-user-1');
      expect(service.currentSession?.source, AuthenticationSource.recoveryCode);
      expect(verifiers.values['verifier-email-user-1'], 'hashed:new-password');
      expect(recoveryCodes.unusedDigests, isNot(contains(code.digest)));
      expect(audits.events.single.details, isNot(contains(code.display)));
    },
  );

  test(
    'GivenMalformedRecoveryCode_WhenRecovering_ThenVerifierIsUntouchedAndFailureIsRedacted',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();

      final result = await service.recoverLocalAccount(
        'person@example.com',
        'malformed-code',
        'new-password',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.recovery.invalid',
      );
      expect(verifiers.writes, isEmpty);
      expect(audits.events.single.details, isNot(contains('malformed-code')));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenAlreadyUsedRecoveryCode_WhenRecovering_ThenVerifierIsUntouchedAndFailureIsAudited',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      final usedCode = RecoveryCode.generate(Random(29));

      final result = await service.recoverLocalAccount(
        'person@example.com',
        usedCode.display,
        'new-password',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(verifiers.writes, isEmpty);
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.failure);
      expect(audits.events.single.details, isNot(contains(usedCode.display)));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenRecoveryMetadataUpdateFailure_WhenRecovering_ThenCodeStaysSpentAndFailureIsAudited',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      users.failWhenUpdating = true;
      final code = RecoveryCode.generate(Random(31));
      recoveryCodes.unusedDigests.add(code.digest);

      final result = await service.recoverLocalAccount(
        'person@example.com',
        code.display,
        'new-password',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(recoveryCodes.unusedDigests, isNot(contains(code.digest)));
      expect(verifiers.values['verifier-email-user-1'], 'hashed:new-password');
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.failure);
      expect(audits.events.single.details, isNot(contains(code.display)));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenRecoverySuccessAuditFailure_WhenRecovering_ThenCodeStaysSpentAndSessionIsNotOpened',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      audits.failWhenAppending = true;
      final code = RecoveryCode.generate(Random(37));
      recoveryCodes.unusedDigests.add(code.digest);

      final result = await service.recoverLocalAccount(
        'person@example.com',
        code.display,
        'new-password',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(recoveryCodes.unusedDigests, isNot(contains(code.digest)));
      expect(verifiers.values['verifier-email-user-1'], 'hashed:new-password');
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenVerifierWriteFailsAfterRecoveryConsumption_WhenRecovering_ThenCodeRemainsSpent',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      final code = RecoveryCode.generate(Random(13));
      recoveryCodes.unusedDigests.add(code.digest);
      verifiers.failWhenWriting = true;

      final result = await service.recoverLocalAccount(
        'person@example.com',
        code.display,
        'new-password',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(recoveryCodes.unusedDigests, isNot(contains(code.digest)));
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.failure);
      expect(audits.events.single.details, isNot(contains(code.display)));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenConcurrentRecoveryAttempts_WhenUsingOneCode_ThenExactlyOneReplacesTheVerifier',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      final code = RecoveryCode.generate(Random(17));
      recoveryCodes.unusedDigests.add(code.digest);
      final competingService = AuthenticationService(
        users: users,
        verifiers: verifiers,
        hasher: hasher,
        audits: audits,
        operatingSystemAuthentication: operatingSystemAuthentication,
        recoveryCodes: recoveryCodes,
        settings: settings,
        googleAuthorization: googleAuthorization,
        externalGateway: externalGateway,
        newRecoveryCodeSet: () => NewRecoveryCodeSet.generate(Random(19)),
        scheduleExpiry: expiryScheduler.schedule,
        clock: () => now,
        newId: _DeterministicIds().next,
      );

      final results = await Future.wait(<Future<Result<AuthenticatedSession>>>[
        service.recoverLocalAccount(
          'person@example.com',
          code.display,
          'first-password',
        ),
        competingService.recoverLocalAccount(
          'person@example.com',
          code.display,
          'second-password',
        ),
      ]);

      expect(results.whereType<Success<AuthenticatedSession>>(), hasLength(1));
      expect(
        results.whereType<FailureResult<AuthenticatedSession>>(),
        hasLength(1),
      );
      expect(recoveryCodes.successfulConsumptions, 1);
    },
  );

  test(
    'GivenRecoveryCodeConsumedBeforeSignOut_WhenOperationBecomesStale_ThenCodeStaysSpentAndVerifierIsUntouched',
    () async {
      users.emailUsers['person@example.com'] = _emailUser();
      final code = RecoveryCode.generate(Random(23));
      recoveryCodes.unusedDigests.add(code.digest);
      final consumed = Completer<void>();
      final release = Completer<void>();
      recoveryCodes.afterSuccessfulConsume = () {
        consumed.complete();
        return release.future;
      };
      final pending = service.recoverLocalAccount(
        'person@example.com',
        code.display,
        'new-password',
      );
      await consumed.future;

      service.signOut();
      release.complete();
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(recoveryCodes.unusedDigests, isNot(contains(code.digest)));
      expect(verifiers.writes, isEmpty);
      expect(service.currentSession, isNull);
    },
  );
}

final class _DeterministicIds {
  var _next = 0;

  String next() {
    _next += 1;
    return 'user-$_next';
  }
}

final class _FakeLocalUserRepository implements LocalUserRepository {
  String? existingEmail;
  final Map<String, LocalUser> emailUsers = <String, LocalUser>{};
  bool failWhenSaving = false;
  bool failWhenDeleting = false;
  bool failWhenUpdating = false;
  final List<LocalUser> saved = <LocalUser>[];
  final List<String> deletedUserIds = <String>[];
  final List<String> lastAuthenticatedUserIds = <String>[];
  final Map<String, LocalUser> _usersByEmail = <String, LocalUser>{};
  LocalUser? _operatingSystemUser;
  Future<LocalUser?> Function(NormalizedEmail email)? findEmail;
  Future<void> Function(LocalUser user)? afterSave;
  final List<String> findEmailInputs = <String>[];

  set operatingSystemUser(LocalUser? value) => _operatingSystemUser = value;

  @override
  Future<LocalUser?> findByEmail(NormalizedEmail email) async {
    findEmailInputs.add(email.value);
    if (findEmail case final callback?) {
      return callback(email);
    }
    final saved = _usersByEmail[email.value];
    if (saved != null) {
      return saved;
    }
    final configured = emailUsers[email.value];
    if (configured != null) {
      return configured;
    }
    if (existingEmail != email.value) {
      return null;
    }
    return LocalUser(
      id: 'user-1',
      email: NormalizedEmail.parse(existingEmail!),
      authenticationMethod: AuthenticationMethod.emailPassword,
      verifierKey: 'verifier-user-1',
      createdAt: DateTime.utc(2026, 8, 5),
      lastAuthenticatedAt: null,
    );
  }

  @override
  Future<LocalUser?> findOperatingSystemUser() async => _operatingSystemUser;

  @override
  Future<void> save(LocalUser user) async {
    if (failWhenSaving) {
      throw const StorageFailure(
        code: 'storage.unavailable',
        message: 'Unavailable.',
      );
    }
    saved.add(user);
    if (user.email case final email?) {
      _usersByEmail[email.value] = user;
    }
    if (user.authenticationMethod == AuthenticationMethod.operatingSystem) {
      _operatingSystemUser = user;
    }
    if (afterSave case final callback?) {
      await callback(user);
    }
  }

  @override
  Future<void> delete(String userId) async {
    deletedUserIds.add(userId);
    if (failWhenDeleting) {
      throw const StorageFailure(
        code: 'storage.user_cleanup',
        message: 'Unavailable.',
      );
    }
    _usersByEmail.removeWhere((_, user) => user.id == userId);
  }

  @override
  Future<void> updateLastAuthenticatedAt(String userId, DateTime value) async {
    if (failWhenUpdating) {
      throw const StorageFailure(
        code: 'storage.user_metadata',
        message: 'Unavailable.',
      );
    }
    lastAuthenticatedUserIds.add(userId);
  }
}

final class _FakePasswordVerifierStore implements PasswordVerifierStore {
  final Map<String, String> values = <String, String>{};
  final Map<String, String> writes = <String, String>{};
  final List<String> deleted = <String>[];
  final List<String> readKeys = <String>[];
  bool failWhenDeleting = false;
  bool failWhenWriting = false;
  Future<void> Function(String key, String verifier)? afterWrite;

  @override
  Future<void> delete(String key) async {
    if (failWhenDeleting) {
      throw const StorageFailure(
        code: 'storage.cleanup',
        message: 'Unavailable.',
      );
    }
    deleted.add(key);
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    readKeys.add(key);
    return values[key];
  }

  @override
  Future<void> write(String key, String verifier) async {
    if (failWhenWriting) {
      throw const StorageFailure(
        code: 'storage.verifier_write',
        message: 'Unavailable.',
      );
    }
    writes[key] = verifier;
    values[key] = verifier;
    if (afterWrite case final callback?) {
      await callback(key, verifier);
    }
  }
}

final class _FakePasswordHasher implements PasswordHasher {
  final List<String> createInputs = <String>[];

  @override
  Future<String> create(String password) async {
    createInputs.add(password);
    return 'hashed:$password';
  }

  @override
  Future<bool> verify(String verifier, String password) async {
    return verifier == 'hashed:$password';
  }
}

final class _FakeAuditRepository implements AuditRepository {
  final List<AuthenticationAuditEvent> events = <AuthenticationAuditEvent>[];
  bool failWhenAppending = false;
  bool failWhenDeleting = false;
  Future<void> Function(AuthenticationAuditEvent event)? afterAppend;
  Future<void> Function(String eventId)? afterDelete;

  @override
  Future<void> append(AuthenticationAuditEvent event) async {
    if (failWhenAppending) {
      throw const StorageFailure(
        code: 'storage.audit',
        message: 'Unavailable.',
      );
    }
    events.add(event);
    if (afterAppend case final callback?) {
      await callback(event);
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    if (failWhenDeleting) {
      throw const StorageFailure(
        code: 'storage.audit_cleanup',
        message: 'Unavailable.',
      );
    }
    events.removeWhere((event) => event.id == eventId);
    if (afterDelete case final callback?) {
      await callback(eventId);
    }
  }
}

final class _FakeOperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  Result<void> result = const Success<void>(null);
  Object? exception;
  Future<Result<void>> Function()? authenticate;
  int attempts = 0;

  @override
  Future<Result<void>> authenticateCurrentUser() async {
    attempts += 1;
    if (exception case final error?) {
      throw error;
    }
    if (authenticate case final callback?) {
      return callback();
    }
    return result;
  }
}

final class _FakeRecoveryCodeRepository implements RecoveryCodeRepository {
  final List<StoredRecoveryCode> saved = <StoredRecoveryCode>[];
  final Set<String> unusedDigests = <String>{};
  bool failWhenSaving = false;
  int successfulConsumptions = 0;
  Future<void> Function()? afterSuccessfulConsume;

  @override
  Future<void> saveAll(String userId, List<StoredRecoveryCode> codes) async {
    if (failWhenSaving) {
      throw const StorageFailure(
        code: 'storage.recovery_codes',
        message: 'Unavailable.',
      );
    }
    saved.addAll(codes);
    unusedDigests.addAll(codes.map((code) => code.digest));
  }

  @override
  Future<bool> consumeUnusedDigest(String digest, DateTime consumedAt) async {
    final consumed = unusedDigests.remove(digest);
    if (!consumed) {
      return false;
    }
    successfulConsumptions += 1;
    if (afterSuccessfulConsume case final callback?) {
      await callback();
    }
    return true;
  }
}

final class _FakeAuthenticationSettingsRepository
    implements AuthenticationSettingsRepository {
  ExternalAuthenticationConfiguration? configuration =
      ExternalAuthenticationConfiguration(
        clientId: 'desktop-client.apps.googleusercontent.com',
        scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
      );

  @override
  Future<ExternalAuthenticationConfiguration?> load() async => configuration;

  @override
  Future<void> save(ExternalAuthenticationConfiguration configuration) async {
    this.configuration = configuration;
  }
}

final class _FakeGoogleBrowserAuthorization
    implements GoogleBrowserAuthorization {
  Future<GoogleIdToken> Function(ExternalAuthenticationConfiguration)?
  authorizeCallback;
  int cancelAttempts = 0;

  @override
  Future<GoogleIdToken> authorize(
    ExternalAuthenticationConfiguration configuration,
  ) async {
    if (authorizeCallback case final callback?) {
      return callback(configuration);
    }
    return const GoogleIdToken('google-id-token');
  }

  @override
  Future<void> cancelActiveAuthorization() async {
    cancelAttempts += 1;
  }
}

final class _FakeExternalAuthenticationGateway
    implements ExternalAuthenticationGateway {
  ExternalTokenGrant grant = ExternalTokenGrant(
    token: _jwtWithPayload(<String, Object?>{'sub': 'external-actor'}),
    expiresAt: DateTime.utc(2026, 8, 5, 13),
    emailVerified: true,
  );
  final List<String> idTokens = <String>[];
  Object? exception;
  Future<ExternalTokenGrant> Function({
    required String scopeId,
    required String idToken,
  })?
  signInCallback;

  @override
  Future<ExternalTokenGrant> signInWithGoogle({
    required String scopeId,
    required String idToken,
  }) async {
    idTokens.add(idToken);
    if (exception case final error?) {
      throw error;
    }
    if (signInCallback case final callback?) {
      return callback(scopeId: scopeId, idToken: idToken);
    }
    return grant;
  }
}

final class _ScheduledExpiry {
  _ScheduledExpiry(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  bool cancelled = false;
}

final class _FakeSessionExpiryScheduler {
  final List<_ScheduledExpiry> scheduled = <_ScheduledExpiry>[];

  List<_ScheduledExpiry> get pendingCallbacks =>
      scheduled.where((expiry) => !expiry.cancelled).toList(growable: false);

  void Function() schedule(Duration delay, void Function() callback) {
    final expiry = _ScheduledExpiry(delay, callback);
    scheduled.add(expiry);
    return () => expiry.cancelled = true;
  }

  void fireNext() {
    final expiry = pendingCallbacks.first;
    expiry.cancelled = true;
    expiry.callback();
  }
}

String _jwtWithPayload(Map<String, Object?> payload) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(<String, Object?>{'alg': 'none'})}.${encode(payload)}.';
}

LocalUser _operatingSystemUser() {
  return LocalUser(
    id: 'os-user-1',
    email: null,
    authenticationMethod: AuthenticationMethod.operatingSystem,
    verifierKey: null,
    createdAt: DateTime.utc(2026, 8, 5),
    lastAuthenticatedAt: null,
  );
}

LocalUser _emailUser() {
  return LocalUser(
    id: 'email-user-1',
    email: NormalizedEmail.parse('person@example.com'),
    authenticationMethod: AuthenticationMethod.emailPassword,
    verifierKey: 'verifier-email-user-1',
    createdAt: DateTime.utc(2026, 8, 5),
    lastAuthenticatedAt: null,
  );
}
