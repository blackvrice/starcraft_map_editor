import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import '../../application/ports/eud_project_store.dart';
import '../../domain/eud/eud_project.dart';
import 'local_map_save_file_gateway.dart';

final class LocalEudProjectStore implements EudProjectStore {
  LocalEudProjectStore({this.fileMover});
  final LocalMapFileMover? fileMover;

  @override
  Future<EudProjectFile> read(String path) async {
    _checkPath(path);
    final bytes = await _readBytes(File(path));
    return EudProjectFile(
      project: EudProject.decode(utf8.decode(bytes)),
      revision: sha256.convert(bytes).toString(),
    );
  }

  Future<Uint8List> _readBytes(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException(
        'EUD project must be a regular file.',
        file.path,
      );
    }
    final before = await file.stat();
    final handle = await file.open();
    try {
      if (await handle.length() > EudProject.maxTextLength) {
        throw const FormatException('EUD project exceeds size limit.');
      }
      final bytes = await handle.read(EudProject.maxTextLength + 1);
      final after = await file.stat();
      if (bytes.length > EudProject.maxTextLength) {
        throw const FormatException('EUD project exceeds size limit.');
      }
      if (before.type != after.type ||
          before.size != after.size ||
          before.modified != after.modified ||
          bytes.length != after.size) {
        throw EudProjectConflict(file.path);
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  Future<void> _requireRevision(
    File file,
    String expected,
    String destination,
  ) async {
    final bytes = await _readBytes(file);
    if (sha256.convert(bytes).toString() != expected) {
      throw EudProjectConflict(destination);
    }
  }

  @override
  Future<EudProjectFile> saveAs(String path, EudProject project) =>
      _write(path, project);

  @override
  Future<EudProjectFile> save(
    String path,
    EudProject project, {
    required String expectedRevision,
  }) => _write(path, project, expectedRevision: expectedRevision);

  Future<EudProjectFile> _write(
    String path,
    EudProject project, {
    String? expectedRevision,
  }) async {
    _checkPath(path);
    final files = LocalMapSaveFileGateway(
      fileMover: fileMover,
      backupValidator: expectedRevision == null
          ? null
          : (backup) => _requireRevision(backup, expectedRevision, path),
    );
    final sameSpelling =
        File(path).absolute.path.replaceAll('\\', '/').toLowerCase() ==
        File(project.mapPath).absolute.path.replaceAll('\\', '/').toLowerCase();
    if (sameSpelling ||
        (await files.destinationExists(project.mapPath) &&
            await files.refersToSameLocation(path, project.mapPath))) {
      throw FileSystemException(
        'The project must not overwrite its map.',
        path,
      );
    }
    if (expectedRevision == null) {
      if (await files.destinationExists(path)) {
        throw FileSystemException('Choose a new EUD project path.', path);
      }
    } else {
      await _requireRevision(File(path), expectedRevision, path);
    }
    final text = project.encode();
    final bytes = utf8.encode(text);
    if (bytes.length > EudProject.maxTextLength) {
      throw const FormatException('EUD project exceeds size limit.');
    }
    final revision = sha256.convert(bytes).toString();
    final workspace = await files.createWorkspace(path);
    String? backupPath;
    String? cleanupWarning;
    try {
      final output = File(workspace.temporaryOutputPath);
      await output.writeAsBytes(bytes, flush: true);
      final verified = await _readBytes(output);
      if (sha256.convert(verified).toString() != revision ||
          EudProject.decode(utf8.decode(verified)).encode() != text) {
        throw const FormatException('EUD project verification failed.');
      }
      if (expectedRevision != null) {
        await _requireRevision(File(path), expectedRevision, path);
      }
      final promotion = await files.promote(
        workspace: workspace,
        destinationPath: path,
        replaceExisting: expectedRevision != null,
      );
      backupPath = promotion.backupPath;
      try {
        await _requireRevision(File(path), revision, path);
      } catch (error) {
        throw EudProjectSaveVerificationFailure(path, backupPath, error);
      }
    } finally {
      try {
        await files.cleanup(workspace);
      } catch (error) {
        cleanupWarning =
            'Temporary project files could not be removed: ${workspace.directoryPath}: $error';
      }
    }
    return EudProjectFile(
      project: project,
      revision: revision,
      backupPath: backupPath,
      cleanupWarning: cleanupWarning,
    );
  }

  void _checkPath(String path) {
    if (path.trim() != path ||
        !File(path).isAbsolute ||
        !path.toLowerCase().endsWith('.eud.json')) {
      throw const FormatException('Use an absolute .eud.json project path.');
    }
  }
}
