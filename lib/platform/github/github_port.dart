import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/common/command_runner.dart';

abstract interface class GitHubPort implements CapabilityProbe {
  Future<CommandResult> authenticationStatus();
}
