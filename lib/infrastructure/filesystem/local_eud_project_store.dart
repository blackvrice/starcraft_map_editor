import 'dart:convert';
import 'dart:io';

import '../../application/ports/eud_project_store.dart';
import '../../application/ports/map_save_file_gateway.dart';
import '../../domain/eud/eud_project.dart';
import 'local_map_save_file_gateway.dart';

final class LocalEudProjectStore implements EudProjectStore {
  LocalEudProjectStore({MapSaveFileGateway? files})
    : _files = files ?? LocalMapSaveFileGateway();
  final MapSaveFileGateway _files;

  @override
  Future<EudProject> read(String path) async {
    _checkPath(path);
    return _readVerified(File(path));
  }

  Future<EudProject> _readVerified(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException(
        'EUD project must be a regular file.',
        file.path,
      );
    }
    final handle = await file.open();
    try {
      if (await handle.length() > EudProject.maxTextLength) {
        throw const FormatException('EUD project exceeds size limit.');
      }
      final bytes = await handle.read(EudProject.maxTextLength + 1);
      if (bytes.length > EudProject.maxTextLength) {
        throw const FormatException('EUD project exceeds size limit.');
      }
      return EudProject.decode(utf8.decode(bytes));
    } finally {
      await handle.close();
    }
  }

  @override
  Future<void> saveAs(String path, EudProject project) async {
    _checkPath(path);
    if (await _files.destinationExists(path) ||
        await _files.refersToSameLocation(path, project.mapPath)) {
      throw FileSystemException('Choose a new EUD project path.', path);
    }
    final text = project.encode();
    if (utf8.encode(text).length > EudProject.maxTextLength) {
      throw const FormatException('EUD project exceeds size limit.');
    }
    final workspace = await _files.createWorkspace(path);
    try {
      final output = File(workspace.temporaryOutputPath);
      await output.writeAsString(text, encoding: utf8, flush: true);
      if ((await _readVerified(output)).encode() != text) {
        throw const FormatException('EUD project verification failed.');
      }
      await _files.promote(
        workspace: workspace,
        destinationPath: path,
        replaceExisting: false,
      );
    } finally {
      await _files.cleanup(workspace);
    }
  }

  void _checkPath(String path) {
    if (path.trim() != path || !path.toLowerCase().endsWith('.eud.json')) {
      throw const FormatException('Use a .eud.json project path.');
    }
  }
}
