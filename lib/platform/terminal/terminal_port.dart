import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/platform/common/capability.dart';

/// The platform adapter surface for the embedded terminal (IR-08).
///
/// It is the application's [TerminalPort] plus the startup capability report,
/// the same shape `GitPort` uses: the feature depends on the narrow port, and
/// the foundation asks the adapter whether a shell exists at all (AF-01).
abstract interface class TerminalCapabilityPort
    implements TerminalPort, CapabilityProbe {}
