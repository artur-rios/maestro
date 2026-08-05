import 'dart:typed_data';

import 'package:maestro/platform/common/capability.dart';

enum AgentCliKind { claudeCode, codex, openCode }

abstract interface class AgentCliPort implements CapabilityProbe {
  AgentCliKind get kind;

  Future<void> write(Uint8List bytes);
}
