import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/capability.dart';

abstract interface class UpdatePort implements CapabilityProbe {
  Future<Result<bool>> checkForUpdate();
}
