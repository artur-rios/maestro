import 'dart:typed_data';

import 'package:maestro/platform/common/capability.dart';

abstract interface class TerminalSession {
  Stream<Uint8List> get output;

  Future<void> write(Uint8List bytes);
  Future<void> close();
}

abstract interface class TerminalPort implements CapabilityProbe {
  Future<TerminalSession> start({required String workingDirectory});
}
