import 'dart:io';

import '../../application/eud/eud_build_configuration.dart';
import '../../application/ports/eud_build_file_gateway.dart';

typedef LocalEudBuildFileMover =
    Future<void> Function(File source, String destinationPath);

final class LocalEudBuildFileGateway implements EudBuildFileGateway {
  LocalEudBuildFileGateway({LocalEudBuildFileMover? fileMover})
    : _fileMover = fileMover ?? _moveFile;

  static const _workspacePrefix = '.starcraft_map_editor_eud_';

  final LocalEudBuildFileMover _fileMover;
  final Set<String> _ownedWorkspacePaths = {};

  @override
  Future<void> validateInputs(EudBuildConfiguration configuration) async {
    await _requireType(
      configuration.baseMapPath,
      FileSystemEntityType.file,
      'The EUD base map must be a regular file.',
    );
    await _requireType(
      configuration.sourceRootPath,
      FileSystemEntityType.directory,
      'The EUD source root must be a regular directory.',
    );
    await _requireType(
      configuration.entrySourcePath,
      FileSystemEntityType.file,
      'The EUD entry source must be a regular file.',
    );

    final destination = File(configuration.outputMapPath).absolute;
    await _requireType(
      destination.parent.path,
      FileSystemEntityType.directory,
      'The EUD output directory must already exist.',
    );
    final destinationType = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    if (destinationType != FileSystemEntityType.notFound &&
        destinationType != FileSystemEntityType.file) {
      throw FileSystemException(
        'The EUD output must be absent or a regular file.',
        destination.path,
      );
    }

    final canonicalSourceRoot = _normalize(
      await Directory(configuration.sourceRootPath).resolveSymbolicLinks(),
    );
    final canonicalEntry = _normalize(
      await File(configuration.entrySourcePath).resolveSymbolicLinks(),
    );
    if (!_isWithin(canonicalSourceRoot, canonicalEntry)) {
      throw FileSystemException(
        'The canonical EUD entry source is outside the source root.',
        configuration.entrySourcePath,
      );
    }
    final canonicalOutputParent = _normalize(
      await destination.parent.resolveSymbolicLinks(),
    );
    if (_isSameOrWithin(canonicalSourceRoot, canonicalOutputParent)) {
      throw FileSystemException(
        'The canonical EUD output directory is inside the source root.',
        destination.parent.path,
      );
    }
  }

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
        // Fall back to resolved comparison paths.
      }
    }

    return await _comparisonPath(leftPath) == await _comparisonPath(rightPath);
  }

  @override
  Future<EudBuildWorkspace> createWorkspace(
    EudBuildConfiguration configuration,
  ) async {
    final destination = File(configuration.outputMapPath).absolute;
    final directory = await destination.parent.createTemp(_workspacePrefix);
    final directoryPath = directory.absolute.path;
    final normalizedDirectoryPath = _normalize(directoryPath);
    _ownedWorkspacePaths.add(normalizedDirectoryPath);

    final workspace = EudBuildWorkspace(
      directoryPath: directoryPath,
      settingsFilePath:
          '$directoryPath${Platform.pathSeparator}build-settings.eds',
      temporaryOutputMapPath:
          '$directoryPath${Platform.pathSeparator}temporary-output.scx',
    );
    try {
      await File(workspace.settingsFilePath).writeAsString(
        _serializeSettings(configuration, workspace),
        flush: true,
      );
      return workspace;
    } on Object {
      _ownedWorkspacePaths.remove(normalizedDirectoryPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      rethrow;
    }
  }

  @override
  Future<EudBuildPromotionResult> promote({
    required EudBuildWorkspace workspace,
    required String destinationPath,
    required bool replaceExisting,
  }) async {
    _requireOwned(workspace);

    final workspaceDirectory = Directory(workspace.directoryPath).absolute;
    final temporaryOutput = File(workspace.temporaryOutputMapPath).absolute;
    if (_normalize(temporaryOutput.parent.path) !=
        _normalize(workspaceDirectory.path)) {
      throw FileSystemException(
        'The EUD temporary output is outside its owned workspace.',
        temporaryOutput.path,
      );
    }

    final destination = File(destinationPath).absolute;
    if (_normalize(destination.parent.path) !=
        _normalize(workspaceDirectory.parent.path)) {
      throw FileSystemException(
        'The EUD build workspace is not beside the destination.',
        destination.path,
      );
    }

    final temporaryOutputType = await FileSystemEntity.type(
      temporaryOutput.path,
      followLinks: false,
    );
    if (temporaryOutputType != FileSystemEntityType.file) {
      throw FileSystemException(
        'The verified EUD output is not a regular file.',
        temporaryOutput.path,
      );
    }

    final destinationType = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    if (destinationType == FileSystemEntityType.notFound) {
      await _fileMover(temporaryOutput, destination.path);
      return EudBuildPromotionResult();
    }
    if (destinationType != FileSystemEntityType.file) {
      throw FileSystemException(
        'Only a regular EUD output file can be replaced.',
        destination.path,
      );
    }
    if (!replaceExisting) {
      throw FileSystemException(
        'The EUD output already exists.',
        destination.path,
      );
    }

    final backupPath = _backupPathFor(
      destinationPath: destination.path,
      workspaceDirectoryPath: workspaceDirectory.path,
    );
    if (await destinationExists(backupPath)) {
      throw FileSystemException(
        'The EUD recovery backup path already exists.',
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
            'The failed EUD promotion left an unexpected destination.',
            destination.path,
          );
        }
        await _fileMover(File(backupPath), destination.path);
      } on Object catch (restorationError) {
        throw EudBuildPromotionRecoveryException(
          destinationPath: destination.path,
          backupPath: backupPath,
          promotionError: promotionError,
          restorationError: restorationError,
        );
      }
      Error.throwWithStackTrace(promotionError, promotionStackTrace);
    }

    return EudBuildPromotionResult(backupPath: backupPath);
  }

  @override
  Future<void> cleanup(EudBuildWorkspace workspace) async {
    final normalizedPath = _normalize(workspace.directoryPath);
    if (!_ownedWorkspacePaths.remove(normalizedPath)) {
      return;
    }
    final directory = Directory(workspace.directoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _requireType(
    String path,
    FileSystemEntityType expected,
    String message,
  ) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type != expected) {
      throw FileSystemException(message, path);
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

  String _serializeSettings(
    EudBuildConfiguration configuration,
    EudBuildWorkspace workspace,
  ) {
    final options = configuration.compilerOptions.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final lines = <String>[
      ':: Generated by StarCraft Map Editor. Do not edit.',
      '[main]',
      'input: ${configuration.baseMapPath}',
      'output: ${workspace.temporaryOutputMapPath}',
      for (final option in options)
        if (option.value.isEmpty)
          option.key
        else
          '${option.key}: ${option.value}',
      '',
      '[freeze]',
      'freeze: 0',
      '',
      '[${configuration.entrySourcePath}]',
      '',
    ];
    return lines.join('\r\n');
  }

  void _requireOwned(EudBuildWorkspace workspace) {
    if (!_ownedWorkspacePaths.contains(_normalize(workspace.directoryPath))) {
      throw FileSystemException(
        'The EUD build workspace is not owned by this application instance.',
        workspace.directoryPath,
      );
    }
  }

  String _backupPathFor({
    required String destinationPath,
    required String workspaceDirectoryPath,
  }) {
    final workspaceName = workspaceDirectoryPath
        .split(RegExp(r'[\\/]'))
        .where((part) => part.isNotEmpty)
        .last;
    final rawToken = workspaceName.startsWith(_workspacePrefix)
        ? workspaceName.substring(_workspacePrefix.length)
        : workspaceName;
    final safeToken = rawToken.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '$destinationPath.backup-eud-$safeToken.bak';
  }

  static Future<void> _moveFile(File source, String destinationPath) async {
    await source.rename(destinationPath);
  }

  bool _isWithin(String root, String candidate) {
    if (candidate == root) {
      return false;
    }
    final prefix = root.endsWith(r'\') ? root : '$root\\';
    return candidate.startsWith(prefix);
  }

  bool _isSameOrWithin(String root, String candidate) {
    return candidate == root || _isWithin(root, candidate);
  }

  String _normalize(String path) =>
      path.replaceAll('/', r'\').replaceAll(RegExp(r'\\+'), r'\').toLowerCase();
}
