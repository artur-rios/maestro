import 'dart:io';

import 'package:maestro/platform/process/linux_group_process_tree.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/windows_job_process_tree.dart';

abstract final class ProcessTreeFactory {
  static NativeProcessTree current() {
    if (Platform.isWindows) {
      return const WindowsJobProcessTree();
    }
    if (Platform.isLinux) {
      return LinuxGroupProcessTree();
    }
    throw UnsupportedError(
      'Process-tree ownership is supported on Windows and Linux.',
    );
  }
}
