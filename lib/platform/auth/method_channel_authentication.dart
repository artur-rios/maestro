import 'package:flutter/services.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/auth/authentication_port.dart';
import 'package:maestro/platform/common/capability.dart';

const _authenticationChannel = MethodChannel(
  'dev.artur-rios.maestro/authentication',
);
const _capabilityId = 'operating-system-authentication';

enum _AuthenticationStatus {
  authenticated,
  denied,
  unavailable,
  transientFailure,
}

final class MethodChannelAuthentication implements AuthenticationPort {
  const MethodChannelAuthentication();

  @override
  Future<Capability> probe() async {
    try {
      final response = await _authenticationChannel.invokeMethod<Object?>(
        'probe',
      );
      return _parseCapability(response);
    } on MissingPluginException {
      return Capability(
        id: _capabilityId,
        state: CapabilityState.unsupported,
        message: 'Operating-system authentication is not supported.',
        remediation: 'Use email and password authentication.',
      );
    } on PlatformException {
      return Capability(
        id: _capabilityId,
        state: CapabilityState.transientFailure,
        message: 'Operating-system authentication could not be inspected.',
        remediation: 'Retry or use email and password authentication.',
      );
    } on Object {
      return _malformedCapability();
    }
  }

  @override
  Future<Result<void>> authenticateCurrentUser() async {
    try {
      final response = await _authenticationChannel.invokeMethod<Object?>(
        'authenticateCurrentUser',
      );
      return _parseAuthentication(response);
    } on MissingPluginException catch (error) {
      return FailureResult<void>(
        PlatformFailure(
          code: 'authentication.operating_system.unavailable',
          message: 'Operating-system authentication is unavailable.',
          remediation: 'Use email and password authentication.',
          cause: error,
        ),
      );
    } on PlatformException catch (error) {
      return FailureResult<void>(
        PlatformFailure(
          code: 'authentication.operating_system.transient_failure',
          message: 'Operating-system authentication could not be completed.',
          remediation: 'Retry or use email and password authentication.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return FailureResult<void>(
        PlatformFailure(
          code: 'authentication.operating_system.invalid_response',
          message: 'The operating-system authentication response was invalid.',
          remediation: 'Use email and password authentication.',
          cause: error,
        ),
      );
    }
  }

  static Capability _parseCapability(Object? response) {
    final payload = _payload(response);
    if (payload == null) {
      return _malformedCapability();
    }
    final status = payload['status'];
    final message = payload['message'];
    final remediation = payload['remediation'];
    if (status is! String ||
        message is! String ||
        message.isEmpty ||
        (remediation != null && remediation is! String)) {
      return _malformedCapability();
    }

    final state = _capabilityState(status);
    if (state == null) {
      return _malformedCapability();
    }
    return Capability(
      id: _capabilityId,
      state: state,
      message: message,
      remediation: remediation as String?,
    );
  }

  static Result<void> _parseAuthentication(Object? response) {
    final payload = _payload(response);
    if (payload == null) {
      return _invalidAuthenticationResponse();
    }
    final statusValue = payload['status'];
    final messageValue = payload['message'];
    final remediationValue = payload['remediation'];
    if (statusValue is! String ||
        (messageValue != null && messageValue is! String) ||
        (remediationValue != null && remediationValue is! String)) {
      return _invalidAuthenticationResponse();
    }

    final status = _authenticationStatus(statusValue);
    final message = messageValue as String?;
    final remediation = remediationValue as String?;
    return switch (status) {
      _AuthenticationStatus.authenticated => const Success<void>(null),
      _AuthenticationStatus.denied => FailureResult<void>(
        SecurityFailure(
          code: 'authentication.operating_system.denied',
          message: message ?? 'Operating-system authentication was denied.',
          remediation:
              remediation ?? 'Retry or use email and password authentication.',
        ),
      ),
      _AuthenticationStatus.unavailable => FailureResult<void>(
        PlatformFailure(
          code: 'authentication.operating_system.unavailable',
          message: message ?? 'Operating-system authentication is unavailable.',
          remediation: remediation ?? 'Use email and password authentication.',
        ),
      ),
      _AuthenticationStatus.transientFailure => FailureResult<void>(
        PlatformFailure(
          code: 'authentication.operating_system.transient_failure',
          message:
              message ??
              'Operating-system authentication could not be completed.',
          remediation:
              remediation ?? 'Retry or use email and password authentication.',
        ),
      ),
      null => _invalidAuthenticationResponse(),
    };
  }

  static Map<Object?, Object?>? _payload(Object? response) {
    return response is Map<Object?, Object?> ? response : null;
  }

  static CapabilityState? _capabilityState(String value) {
    for (final state in CapabilityState.values) {
      if (state.name == value) {
        return state;
      }
    }
    return null;
  }

  static _AuthenticationStatus? _authenticationStatus(String value) {
    for (final status in _AuthenticationStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return null;
  }

  static Capability _malformedCapability() {
    return const Capability(
      id: _capabilityId,
      state: CapabilityState.malformed,
      message:
          'The operating-system authentication host returned an invalid response.',
      remediation:
          'Repair the installation or use email and password authentication.',
    );
  }

  static FailureResult<void> _invalidAuthenticationResponse() {
    return const FailureResult<void>(
      PlatformFailure(
        code: 'authentication.operating_system.invalid_response',
        message: 'The operating-system authentication response was invalid.',
        remediation:
            'Repair the installation or use email and password authentication.',
      ),
    );
  }
}
