import 'dart:typed_data';

import 'package:maestro/core/agents/agent_cli_kind.dart';
import 'package:maestro/platform/common/capability.dart';

export 'package:maestro/core/agents/agent_cli_kind.dart';

abstract interface class AgentCliPort implements CapabilityProbe {
  AgentCliKind get kind;

  Future<void> write(Uint8List bytes);
}
