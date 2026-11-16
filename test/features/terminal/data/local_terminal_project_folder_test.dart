import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/data/local_git_project_validator.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/data/local_terminal_project_folder.dart';

void main() {
  for (final (state, expected)
      in <(ProjectDirectoryState, TerminalFolderAvailability)>[
        (
          ProjectDirectoryState.accessible,
          TerminalFolderAvailability.available,
        ),
        (ProjectDirectoryState.missing, TerminalFolderAvailability.missing),
        (
          ProjectDirectoryState.notDirectory,
          TerminalFolderAvailability.inaccessible,
        ),
        (
          ProjectDirectoryState.inaccessible,
          TerminalFolderAvailability.inaccessible,
        ),
      ]) {
    final given = '${state.name[0].toUpperCase()}${state.name.substring(1)}';
    final then =
        '${expected.name[0].toUpperCase()}${expected.name.substring(1)}';
    test(
      'Given${given}Folder_WhenAvailabilityIsChecked_ThenItIs$then',
      () async {
        // Given
        final access = _Access(state);

        // When
        final availability = await LocalTerminalProjectFolder(access: access)
            .availability('/repo');

        // Then
        expect(availability, expected);
        expect(access.inspected, <String>['/repo']);
      },
    );
  }

  test(
    'GivenTheDefaultAccess_WhenARealFolderIsChecked_ThenItIsAvailable',
    () async {
      final root = await Directory.systemTemp.createTemp('maestro-terminal-');
      addTearDown(() => root.delete(recursive: true));

      expect(
        await const LocalTerminalProjectFolder().availability(root.path),
        TerminalFolderAvailability.available,
      );
      expect(
        await const LocalTerminalProjectFolder().availability(
          '${root.path}${Platform.pathSeparator}missing',
        ),
        TerminalFolderAvailability.missing,
      );
    },
  );
}

final class _Access implements ProjectDirectoryAccess {
  _Access(this._state);

  final ProjectDirectoryState _state;
  final List<String> inspected = <String>[];

  @override
  Future<ProjectDirectoryState> inspect(String path) async {
    inspected.add(path);
    return _state;
  }
}
