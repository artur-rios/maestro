import 'package:file_selector/file_selector.dart';
import 'package:maestro/features/projects/application/project_service.dart';

final class FileSelectorProjectFolderPicker implements ProjectFolderPicker {
  const FileSelectorProjectFolderPicker();

  @override
  Future<String?> chooseFolder() async {
    try {
      return await getDirectoryPath(confirmButtonText: 'Register project');
    } on Object {
      throw const ProjectFolderPickerException();
    }
  }
}
