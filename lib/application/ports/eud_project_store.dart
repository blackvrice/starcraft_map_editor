import '../../domain/eud/eud_project.dart';

final class EudProjectFile {
  const EudProjectFile({
    required this.project,
    required this.revision,
    this.backupPath,
    this.cleanupWarning,
  });
  final EudProject project;

  /// Opaque revision of the exact bytes read/written, not normalized JSON.
  final String revision;
  final String? backupPath;
  final String? cleanupWarning;
}

final class EudProjectConflict implements Exception {
  const EudProjectConflict(this.path);
  final String path;
  @override
  String toString() =>
      'The EUD project changed outside the editor: $path. '
      'Reopen it or use Save Project As to preserve both versions.';
}

final class EudProjectSaveVerificationFailure implements Exception {
  const EudProjectSaveVerificationFailure(
    this.path,
    this.backupPath,
    this.cause,
  );
  final String path;
  final String? backupPath;
  final Object cause;
  @override
  String toString() =>
      'The saved EUD project could not be verified: $path. '
      'Recovery backup: ${backupPath ?? 'none (new file)'}. $cause';
}

abstract interface class EudProjectStore {
  Future<EudProjectFile> read(String path);

  /// Writes to a new .eud.json path only; existing files must not be replaced.
  Future<EudProjectFile> saveAs(String path, EudProject project);

  /// Replaces only the exact revision read or successfully saved by this session.
  /// Keeps the previous bytes in a recovery backup.
  Future<EudProjectFile> save(
    String path,
    EudProject project, {
    required String expectedRevision,
  });
}
