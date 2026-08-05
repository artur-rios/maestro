import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/common/command_runner.dart';

abstract interface class GitPort implements CapabilityProbe {
  Future<CommandResult> status(String repositoryPath);
}
