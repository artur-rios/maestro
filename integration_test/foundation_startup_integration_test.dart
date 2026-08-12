import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/appearance/application/appearance_preference_repository.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
import 'package:maestro/features/foundation/application/foundation_probe.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:maestro/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GivenCleanProfile_WhenMaestroStarts_ThenFoundationBecomesOperational',
    (tester) async {
      final appearanceController = AppearanceController(
        repository: _AppearancePreferenceRepository(),
        initialMode: AppearanceMode.system,
      );
      addTearDown(appearanceController.dispose);
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: appearanceController,
          authenticationService: _authenticationService(),
          foundationProbes: <FoundationProbe>[_ReadyProbe()],
        ),
      );
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Foundation ready'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenProductionComposition_WhenStarted_ThenAuthenticationGateIsVisible',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        find.text('Sign in with your operating system'),
        findsOneWidget,
        reason: _visibleText(tester),
      );
      expect(find.bySemanticsLabel(RegExp(r'^Foundation ')), findsNothing);
    },
  );
}

final class _AppearancePreferenceRepository
    implements AppearancePreferenceRepository {
  @override
  Future<AppearanceMode> load() async => AppearanceMode.system;

  @override
  Future<void> save(AppearanceMode mode) async {}
}

AuthenticationService _authenticationService() {
  var nextId = 0;
  final repository = _AuthenticationRepository();
  return AuthenticationService(
    users: repository,
    verifiers: const _PasswordVerifierStore(),
    hasher: const _PasswordHasher(),
    audits: repository,
    operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
    clock: () => DateTime.utc(2026, 8, 5),
    newId: () => 'id-${nextId++}',
  );
}

String _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data)
    .whereType<String>()
    .join(' | ');

final class _ReadyProbe implements FoundationProbe {
  @override
  String get id => 'clean-profile';

  @override
  Future<FoundationCheck> probe() async => const FoundationCheck(
    id: 'clean-profile',
    health: FoundationHealth.ready,
    message: 'Foundation services are operational.',
  );
}

final class _AuthenticationRepository
    implements LocalUserRepository, AuditRepository {
  LocalUser? operatingSystemUser;

  @override
  Future<void> append(AuthenticationAuditEvent event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Future<void> delete(String userId) async {}

  @override
  Future<LocalUser?> findByEmail(NormalizedEmail email) async => null;

  @override
  Future<LocalUser?> findOperatingSystemUser() async => operatingSystemUser;

  @override
  Future<void> save(LocalUser user) async => operatingSystemUser = user;

  @override
  Future<void> updateLastAuthenticatedAt(String userId, DateTime value) async {}
}

final class _PasswordVerifierStore implements PasswordVerifierStore {
  const _PasswordVerifierStore();

  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String verifier) async {}
}

final class _PasswordHasher implements PasswordHasher {
  const _PasswordHasher();

  @override
  Future<String> create(String password) async => 'test-verifier';

  @override
  Future<bool> verify(String verifier, String password) async => false;
}

final class _OperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  const _OperatingSystemAuthenticator();

  @override
  Future<Result<void>> authenticateCurrentUser() async {
    return const Success<void>(null);
  }
}
