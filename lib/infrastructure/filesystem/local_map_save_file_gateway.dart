import 'dart:io';

import '../../application/ports/map_save_file_gateway.dart';

class LocalMapSaveFileGateway implements MapSaveFileGateway {
  final Set<String> _ownedWorkspacePaths = {};

  @override
  Future<bool> destinationExists(String path) async {
    return await FileSystemEntity.type(path) != FileSystemEntityType.notFound;
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
  Future<void> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
  }) async {
    _requireOwned(workspace);
    if (await destinationExists(destinationPath)) {
      throw FileSystemException(
        'The Save As destination already exists.',
        destinationPath,
      );
    }

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
    await temporaryOutput.rename(destination.path);
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

  String _normalize(String path) =>
      path.replaceAll('/', r'\').replaceAll(RegExp(r'\\+'), r'\').toLowerCase();
}
