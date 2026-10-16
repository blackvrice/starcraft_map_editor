import 'dart:io';
import '../../application/ports/unit_creep_map_preparation_gateway.dart';
import 'local_map_save_file_gateway.dart';

final class LocalCreepCaptureWorkspaceGateway
    implements CreepCaptureWorkspaceGateway {
  LocalCreepCaptureWorkspaceGateway({this.temporaryRoot});
  final String? temporaryRoot;
  final _owned = <CreepCaptureWorkspace>{};
  final _paths = LocalMapSaveFileGateway();

  @override
  Future<CreepCaptureWorkspace> create() async {
    final root = Directory(temporaryRoot ?? Directory.systemTemp.path);
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw FileSystemException(
        'Capture root must be a regular directory.',
        root.path,
      );
    }
    final directory = await root.createTemp('starcraft_creep_capture_');
    final canonical = await directory.resolveSymbolicLinks();
    final workspace = CreepCaptureWorkspace(
      directoryPath: canonical,
      mapPath: '$canonical${Platform.pathSeparator}input.scx',
    );
    _owned.add(workspace);
    return workspace;
  }

  @override
  Future<bool> sameLocation(String left, String right) =>
      _paths.refersToSameLocation(left, right);

  @override
  Future<void> cleanup(CreepCaptureWorkspace workspace) async {
    if (!_owned.contains(workspace)) {
      throw StateError('Foreign capture workspace.');
    }
    final type = await FileSystemEntity.type(
      workspace.directoryPath,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      _owned.remove(workspace);
      return;
    }
    if (type != FileSystemEntityType.directory ||
        await Directory(workspace.directoryPath).resolveSymbolicLinks() !=
            workspace.directoryPath) {
      throw StateError('Capture workspace was replaced or redirected.');
    }
    final mapType = await FileSystemEntity.type(
      workspace.mapPath,
      followLinks: false,
    );
    if (mapType != FileSystemEntityType.notFound &&
        mapType != FileSystemEntityType.file) {
      throw StateError('Capture map is not a regular file.');
    }
    if (mapType == FileSystemEntityType.file) {
      await File(workspace.mapPath).delete();
    }
    // Never recursively remove unexpected files. Keep ownership if cleanup fails.
    await Directory(workspace.directoryPath).delete();
    _owned.remove(workspace);
  }
}
