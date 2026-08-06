import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/auth/authentication_port.dart';
import 'package:maestro/platform/auth/method_channel_authentication.dart';
import 'package:maestro/platform/common/capability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.artur-rios.maestro/authentication');
  late Map<String, Object?> replies;

  setUp(() {
    replies = <String, Object?>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (!replies.containsKey(call.method)) {
            throw PlatformException(
              code: 'unexpected-method',
              message: call.method,
            );
          }
          return replies[call.method];
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'GivenNativeAvailability_WhenProbing_ThenTypedCapabilityIsReturned',
    () async {
      replies['probe'] = <String, Object?>{
        'status': 'available',
        'message': 'Operating-system authentication is available.',
      };
      const AuthenticationPort adapter = MethodChannelAuthentication();

      final capability = await adapter.probe();

      expect(capability.id, 'operating-system-authentication');
      expect(capability.state, CapabilityState.available);
      expect(
        capability.message,
        'Operating-system authentication is available.',
      );
      expect(capability.remediation, isNull);
    },
  );

  test(
    'GivenNativeMissingVerifier_WhenProbing_ThenRemediationIsPreserved',
    () async {
      replies['probe'] = <String, Object?>{
        'status': 'missing',
        'message': 'No authentication verifier is configured.',
        'remediation': 'Configure operating-system credentials and retry.',
      };
      const adapter = MethodChannelAuthentication();

      final capability = await adapter.probe();

      expect(capability.state, CapabilityState.missing);
      expect(
        capability.remediation,
        'Configure operating-system credentials and retry.',
      );
    },
  );

  test(
    'GivenUnknownNativeProbeStatus_WhenProbing_ThenCapabilityIsMalformed',
    () async {
      replies['probe'] = <String, Object?>{
        'status': 'surprising',
        'message': 'Unrecognized response.',
      };
      const adapter = MethodChannelAuthentication();

      final capability = await adapter.probe();

      expect(capability.state, CapabilityState.malformed);
      expect(capability.message, contains('invalid response'));
    },
  );

  test(
    'GivenMalformedNativeProbePayloads_WhenProbing_ThenEveryResponseFailsClosed',
    () async {
      const malformedPayloads = <Object?>[
        null,
        42,
        <String, Object?>{},
        <String, Object?>{'status': 7, 'message': 'Available.'},
        <String, Object?>{'status': 'available'},
        <String, Object?>{'status': 'available', 'message': 7},
        <String, Object?>{
          'status': 'available',
          'message': 'Available.',
          'remediation': 7,
        },
      ];
      const adapter = MethodChannelAuthentication();

      for (final payload in malformedPayloads) {
        replies['probe'] = payload;

        final capability = await adapter.probe();

        expect(
          capability.state,
          CapabilityState.malformed,
          reason: 'Payload should fail closed: $payload',
        );
      }
    },
  );

  test(
    'GivenNativeAuthentication_WhenAuthenticating_ThenSuccessIsReturned',
    () async {
      replies['authenticateCurrentUser'] = <String, Object?>{
        'status': 'authenticated',
      };
      const adapter = MethodChannelAuthentication();

      final result = await adapter.authenticateCurrentUser();

      expect(result, isA<Success<void>>());
    },
  );

  test(
    'GivenNativeDenial_WhenAuthenticating_ThenSecurityFailureIsReturned',
    () async {
      replies['authenticateCurrentUser'] = <String, Object?>{
        'status': 'denied',
        'message': 'Operating-system authentication was denied.',
      };
      const adapter = MethodChannelAuthentication();

      final result = await adapter.authenticateCurrentUser();

      expect(result, isA<FailureResult<void>>());
      final failure = (result as FailureResult<void>).failure;
      expect(failure, isA<SecurityFailure>());
      expect(failure.code, 'authentication.operating_system.denied');
    },
  );

  test(
    'GivenUnavailableNativeVerifier_WhenAuthenticating_ThenPlatformFailureIsReturned',
    () async {
      replies['authenticateCurrentUser'] = <String, Object?>{
        'status': 'unavailable',
        'message': 'Operating-system authentication is unavailable.',
        'remediation': 'Use email and password authentication.',
      };
      const adapter = MethodChannelAuthentication();

      final result = await adapter.authenticateCurrentUser();

      expect(result, isA<FailureResult<void>>());
      final failure = (result as FailureResult<void>).failure;
      expect(failure, isA<PlatformFailure>());
      expect(failure.code, 'authentication.operating_system.unavailable');
      expect(failure.remediation, 'Use email and password authentication.');
    },
  );

  test(
    'GivenUnknownNativeAuthenticationStatus_WhenAuthenticating_ThenResponseFailsClosed',
    () async {
      replies['authenticateCurrentUser'] = <String, Object?>{
        'status': 'surprising',
      };
      const adapter = MethodChannelAuthentication();

      final result = await adapter.authenticateCurrentUser();

      expect(result, isA<FailureResult<void>>());
      final failure = (result as FailureResult<void>).failure;
      expect(failure, isA<PlatformFailure>());
      expect(failure.code, 'authentication.operating_system.invalid_response');
    },
  );

  test(
    'GivenMalformedNativeAuthenticationPayloads_WhenAuthenticating_ThenEveryResponseFailsClosed',
    () async {
      const malformedPayloads = <Object?>[
        null,
        42,
        <String, Object?>{},
        <String, Object?>{'status': 7},
        <String, Object?>{'status': 'denied', 'message': 7},
        <String, Object?>{'status': 'unavailable', 'remediation': 7},
      ];
      const adapter = MethodChannelAuthentication();

      for (final payload in malformedPayloads) {
        replies['authenticateCurrentUser'] = payload;

        final result = await adapter.authenticateCurrentUser();

        expect(result, isA<FailureResult<void>>(), reason: '$payload');
        final failure = (result as FailureResult<void>).failure;
        expect(
          failure.code,
          'authentication.operating_system.invalid_response',
          reason: 'Payload should fail closed: $payload',
        );
      }
    },
  );

  test(
    'GivenMissingNativeChannel_WhenAuthenticating_ThenUnavailableFailureIsReturned',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      const adapter = MethodChannelAuthentication();

      final result = await adapter.authenticateCurrentUser();

      expect(result, isA<FailureResult<void>>());
      final failure = (result as FailureResult<void>).failure;
      expect(failure, isA<PlatformFailure>());
      expect(failure.code, 'authentication.operating_system.unavailable');
    },
  );

  test(
    'GivenSensitiveNativeExceptions_WhenAuthenticating_ThenNoExceptionDataCrossesTheBoundary',
    () async {
      const sentinel = 'sentinel-native-secret';
      final nativeErrors = <Object>[
        PlatformException(
          code: sentinel,
          message: sentinel,
          details: <String, Object?>{'payload': sentinel},
        ),
        StateError(sentinel),
      ];
      const adapter = MethodChannelAuthentication();

      for (final nativeError in nativeErrors) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw nativeError;
            });

        final result = await adapter.authenticateCurrentUser();

        expect(result, isA<FailureResult<void>>());
        final failure = (result as FailureResult<void>).failure;
        expect(failure.cause, isNull);
        final exposedFields = <Object?>[
          failure.code,
          failure.message,
          failure.remediation,
          failure.cause,
        ].join(' ');
        expect(exposedFields, isNot(contains(sentinel)));
      }
    },
  );
}
