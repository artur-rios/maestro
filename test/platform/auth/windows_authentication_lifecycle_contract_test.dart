import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'GivenAsyncWindowsHelloCallbacks_WhenRunnerTearsDown_ThenSharedReplyGateSuppressesBothOperations',
    () async {
      final root = Directory.current.path;
      final header = await File(
        p.join(root, 'windows', 'runner', 'flutter_window.h'),
      ).readAsString();
      final source = await File(
        p.join(root, 'windows', 'runner', 'flutter_window.cpp'),
      ).readAsString();

      expect(header, contains('std::shared_ptr<AuthenticationReplyGate>'));
      expect(
        RegExp(r'\[shared_result, reply_gate\]').allMatches(source),
        hasLength(2),
      );
      expect(
        RegExp(r'reply_gate->ReplyIfActive\(').allMatches(source).length,
        greaterThanOrEqualTo(4),
      );
      final deactivate = source.indexOf(
        'authentication_reply_gate_->Deactivate();',
      );
      final controllerTeardown = source.indexOf(
        'flutter_controller_ = nullptr;',
      );
      expect(deactivate, greaterThanOrEqualTo(0));
      expect(controllerTeardown, greaterThan(deactivate));
    },
  );
}
