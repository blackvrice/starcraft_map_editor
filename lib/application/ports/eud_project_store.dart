import '../../domain/eud/eud_project.dart';

abstract interface class EudProjectStore {
  Future<EudProject> read(String path);

  /// Writes to a new .eud.json path only; existing files must not be replaced.
  Future<void> saveAs(String path, EudProject project);
}
