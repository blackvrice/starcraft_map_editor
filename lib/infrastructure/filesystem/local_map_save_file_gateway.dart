import 'dart:io';

import '../../application/ports/map_save_file_gateway.dart';

typedef LocalMapFileMover =
    Future<void> Function(File source, String destinationPath);

class LocalMapSaveFileGateway implements MapSaveFileGateway {
  LocalMapSaveFileGateway({LocalMapFileMover? fileMover})
    : _fileMover = fileMover ?? _moveFile;

  final LocalMapFileMover _fileMover;
  final Set<String> _ownedWorkspacePaths = {};

  @override
  Future<bool> destinationExists(String path) async {
    return await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.notFound;
  }

  @override
  Future<bool> refersToSameLocation(String leftPath, String rightPath) async {
    if (await destinationExists(leftPath) &&
        await destinationExists(rightPath)) {
      try {
        return await FileSystemEntity.identical(leftPath, rightPath);
      } on FileSystemException {
        // Fall back to normalized resolved paths.
      }
    }

    final left = await _comparisonPath(leftPath);
    final right = await _comparisonPath(rightPath);
    return left == right;
  }

  @override
  Future<MapSaveWorkspace> createWorkspace(String destinationPath) async {
    final destination = File(destinationPath).absolute;
    final parent = destination.parent;
    final extension = destination.path.toLowerCase().endsWith('.scm')
        ? '.scm'
        : '.scx';
    final directory = await parent.createTemp('.starcraft_map_editor_save_');
    final directoryPath = _normalize(directory.absolute.path);
    _ownedWorkspacePaths.add(directoryPath);
    return MapSaveWorkspace(
      directoryPath: directory.absolute.path,
      temporaryOutputPath:
          '${directory.absolute.path}${Platform.pathSeparator}'
          'temporary-map$extension',
    );
  }

  @override
  Future<MapSavePromotionResult> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
    required bool replaceExisting,
  }) async {
    _requireOwned(workspace);

    final workspaceDirectory = Directory(workspace.directoryPath).absolute;
    final temporaryOutput = File(workspace.temporaryOutputPath).absolute;
    if (_normalize(temporaryOutput.parent.path) !=
        _normalize(workspaceDirectory.path)) {
      throw FileSystemException(
        'The temporary output is outside its owned workspace.',
        temporaryOutput.path,
      );
    }

    final destination = File(destinationPath).absolute;
    if (_normalize(destination.parent.path) !=
        _normalize(workspaceDirectory.parent.path)) {
      throw FileSystemException(
        'The Save As workspace is not beside the destination.',
        destination.path,
      );
    }

    final temporaryOutputType = await FileSystemEntity.type(
      temporaryOutput.path,
      followLinks: false,
    );
    if (temporaryOutputType != FileSystemEntityType.file) {
      throw FileSystemException(
        'The verified temporary output is not a regular file.',
        temporaryOutput.path,
      );
    }

    final destinationType = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    if (destinationType == FileSystemEntityType.notFound) {
      await _fileMover(temporaryOutput, destination.path);
      return MapSavePromotionResult();
    }
    if (destinationType != FileSystemEntityType.file) {
      throw FileSystemException(
        'Only a regular destination file can be replaced.',
        destination.path,
      );
    }
    if (!replaceExisting) {
      throw FileSystemException(
        'The Save As destination already exists.',
        destination.path,
      );
    }

    final backupPath = _backupPathFor(
      destinationPath: destination.path,
      workspaceDirectoryPath: workspaceDirectory.path,
    );
    if (await destinationExists(backupPath)) {
      throw FileSystemException(
        'The recovery backup path already exists.',
        backupPath,
      );
    }

    await _fileMover(destination, backupPath);
    try {
      await _fileMover(temporaryOutput, destination.path);
    } on Object catch (promotionError, promotionStackTrace) {
      try {
        if (await destinationExists(destination.path)) {
          throw FileSystemException(
            'The failed promotion left an unexpected destination in place.',
            destination.path,
          );
        }
        await _fileMover(File(backupPath), destination.path);
      } on Object catch (restorationError) {
        throw MapSavePromotionRecoveryException(
          destinationPath: destination.path,
          backupPath: backupPath,
          promotionError: promotionError,
          restorationError: restorationError,
        );
      }
      Error.throwWithStackTrace(promotionError, promotionStackTrace);
    }

    return MapSavePromotionResult(backupPath: backupPath);
  }

  @override
  Future<void> cleanup(MapSaveWorkspace workspace) async {
    final normalizedPath = _normalize(workspace.directoryPath);
    if (!_ownedWorkspacePaths.remove(normalizedPath)) {
      return;
    }
    final directory = Directory(workspace.directoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<String> _comparisonPath(String path) async {
    final file = File(path).absolute;
    if (await destinationExists(file.path)) {
      try {
        return _normalize(await file.resolveSymbolicLinks());
      } on FileSystemException {
        return _normalize(file.path);
      }
    }

    final resolvedParent = await file.parent.resolveSymbolicLinks();
    final name = file.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    return _normalize('$resolvedParent${Platform.pathSeparator}$name');
  }

  void _requireOwned(MapSaveWorkspace workspace) {
    if (!_ownedWorkspacePaths.contains(_normalize(workspace.directoryPath))) {
      throw FileSystemException(
        'The Save As workspace is not owned by this application instance.',
        workspace.directoryPath,
      );
    }
  }

  String _backupPathFor({
    required String destinationPath,
    required String workspaceDirectoryPath,
  }) {
    const workspacePrefix = '.starcraft_map_editor_save_';
    final workspaceName = workspaceDirectoryPath
        .split(RegExp(r'[\\/]'))
        .where((part) => part.isNotEmpty)
        .last;
    final rawToken = workspaceName.startsWith(workspacePrefix)
        ? workspaceName.substring(workspacePrefix.length)
        : workspaceName;
    final safeToken = rawToken.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '$destinationPath.backup-$safeToken.bak';
  }

  static Future<void> _moveFile(File source, String destinationPath) async {
    await source.rename(destinationPath);
  }

  String _normalize(String path) =>
      path.replaceAll('/', r'\').replaceAll(RegExp(r'\\+'), r'\').toLowerCase();
}
