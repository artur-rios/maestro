import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/capability.dart';

abstract interface class AuthenticationPort implements CapabilityProbe {
  Future<Result<void>> authenticateCurrentUser();
}
