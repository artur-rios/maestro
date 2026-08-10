import 'package:maestro/features/delivery/application/autonomous_delivery_port.dart';
import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/common/command_runner.dart';

abstract interface class GitHubPort
    implements CapabilityProbe, AutonomousDeliveryPort {
  Future<CommandResult> authenticationStatus();
}
