import 'dart:io';

import '../../application/ports/eud_tool_inspector.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

final class LocalEudToolInspector implements EudToolInspector {
  LocalEudToolInspector({
    Iterable<EudToolVersion>? supportedVersions,
    bool Function()? isWindows,
  }) : supportedVersions = Set.unmodifiable(
         supportedVersions ?? [EudToolVersion.parse('0.10.2.5')],
       ),
       _isWindows = isWindows ?? (() => Platform.isWindows) {
    if (this.supportedVersions.isEmpty) {
      throw ArgumentError.value(
        supportedVersions,
        'supportedVersions',
        'At least one supported euddraft version is required.',
      );
    }
  }

  static const maximumVersionFileBytes = 64;
  static const executableName = 'euddraft.exe';
  static const versionFileName = 'VERSION';
  static const _requiredCompanionPaths = [
    'libepScriptLib.dll',
    'python3.dll',
    'license.txt',
    'lib/library.zip',
    'lib/eudplib.bindings._rust.pyd',
  ];

  final Set<EudToolVersion> supportedVersions;
  final bool Function() _isWindows;

  @override
  Future<EudToolInspectionResult> inspect(
    EudToolInspectionRequest request,
  ) async {
    if (!_isWindows()) {
      return _failure(
        code: EudToolDiagnosticCodes.platformUnsupported,
        message: 'euddraft inspection is supported only on Windows.',
        remediation: 'Run the editor on Windows 10 or Windows 11.',
      );
    }

    final candidate = request.selectedCandidate;
    if (candidate == null) {
      return _failure(
        code: EudToolDiagnosticCodes.pathNotConfigured,
        message: 'An euddraft installation path has not been configured.',
        remediation: 'Select the extracted euddraft directory or euddraft.exe.',
      );
    }

    try {
      return await _inspectCandidate(candidate);
    } on Object catch (error, stackTrace) {
      return _failure(
        code: EudToolDiagnosticCodes.inspectionFailed,
        message: 'The euddraft installation could not be inspected.',
        filePath: candidate.path,
        remediation: 'Check path permissions and retry.',
        rawDetails: '$error\n$stackTrace',
      );
    }
  }

  Future<EudToolInspectionResult> _inspectCandidate(
    EudToolPathCandidate candidate,
  ) async {
    if (!File(candidate.path).isAbsolute) {
      return _failure(
        code: EudToolDiagnosticCodes.pathInvalid,
        message: 'The euddraft path must be an absolute Windows path.',
        filePath: candidate.path,
        remediation: 'Select the path using the editor settings.',
      );
    }

    final configuredType = await FileSystemEntity.type(
      candidate.path,
      followLinks: false,
    );
    late final File executable;
    if (configuredType == FileSystemEntityType.directory) {
      executable = File(
        '${Directory(candidate.path).absolute.path}'
        '${Platform.pathSeparator}$executableName',
      );
    } else if (configuredType == FileSystemEntityType.file) {
      executable = File(candidate.path).absolute;
      if (_basename(executable.path).toLowerCase() != executableName) {
        return _failure(
          code: EudToolDiagnosticCodes.pathInvalid,
          message: 'The configured file is not euddraft.exe.',
          filePath: executable.path,
          remediation:
              'Select the official euddraft.exe or its installation folder.',
        );
      }
    } else if (configuredType == FileSystemEntityType.notFound) {
      return _failure(
        code: EudToolDiagnosticCodes.executableMissing,
        message: 'The configured euddraft path does not exist.',
        filePath: candidate.path,
        remediation: 'Extract the official euddraft release and retry.',
      );
    } else {
      return _failure(
        code: EudToolDiagnosticCodes.pathInvalid,
        message:
            'The configured euddraft path is not a regular file or folder.',
        filePath: candidate.path,
        remediation: 'Select a local extracted euddraft installation.',
      );
    }

    final executableType = await FileSystemEntity.type(
      executable.path,
      followLinks: false,
    );
    if (executableType != FileSystemEntityType.file ||
        await executable.length() == 0) {
      return _failure(
        code: EudToolDiagnosticCodes.executableMissing,
        message: 'The installation does not contain a usable euddraft.exe.',
        filePath: executable.path,
        remediation: 'Re-extract the official euddraft release.',
      );
    }

    final installation = executable.parent.absolute;
    final versionFile = File(
      '${installation.path}${Platform.pathSeparator}$versionFileName',
    );
    final versionType = await FileSystemEntity.type(
      versionFile.path,
      followLinks: false,
    );
    if (versionType != FileSystemEntityType.file) {
      return _failure(
        code: EudToolDiagnosticCodes.versionMissing,
        message: 'The euddraft VERSION file is missing.',
        filePath: versionFile.path,
        remediation: 'Use a complete official euddraft release archive.',
      );
    }

    final versionLength = await versionFile.length();
    if (versionLength == 0 || versionLength > maximumVersionFileBytes) {
      return _failure(
        code: EudToolDiagnosticCodes.versionInvalid,
        message: 'The euddraft VERSION file has an invalid size.',
        filePath: versionFile.path,
        remediation: 'Re-extract the official euddraft release.',
        rawDetails:
            'actualBytes=$versionLength; '
            'maximumBytes=$maximumVersionFileBytes',
      );
    }

    final versionText = await versionFile.readAsString();
    final version = EudToolVersion.tryParse(versionText);
    if (version == null) {
      return _failure(
        code: EudToolDiagnosticCodes.versionInvalid,
        message: 'The euddraft VERSION value is not recognized.',
        filePath: versionFile.path,
        remediation: 'Use an official four-component euddraft release.',
        rawDetails: 'value=${versionText.trim()}',
      );
    }
    if (!supportedVersions.contains(version)) {
      return _failure(
        code: EudToolDiagnosticCodes.versionUnsupported,
        message: 'euddraft $version is not supported by this editor.',
        filePath: executable.path,
        remediation:
            'Install a supported release: '
            '${supportedVersions.map((value) => value.toString()).join(', ')}.',
        rawDetails: 'detectedVersion=$version',
      );
    }

    final companionPaths = <String>[];
    final missingCompanions = <String>[];
    for (final relativePath in _requiredCompanionPaths) {
      final path = _joinRelative(installation.path, relativePath);
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.file && await File(path).length() > 0) {
        companionPaths.add(File(path).absolute.path);
      } else {
        missingCompanions.add(relativePath);
      }
    }

    final runtimeDlls = <String>[];
    await for (final entity in installation.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = _basename(entity.path);
      if (!RegExp(
        r'^python3[0-9]+\.dll$',
        caseSensitive: false,
      ).hasMatch(name)) {
        continue;
      }
      if (await entity.length() > 0) {
        runtimeDlls.add(entity.absolute.path);
      }
    }
    if (runtimeDlls.isEmpty) {
      missingCompanions.add('python3<runtime>.dll');
    } else {
      runtimeDlls.sort();
      companionPaths.addAll(runtimeDlls);
    }

    if (missingCompanions.isNotEmpty) {
      return _failure(
        code: EudToolDiagnosticCodes.companionMissing,
        message: 'The euddraft installation is incomplete.',
        filePath: installation.path,
        remediation: 'Re-extract the complete official euddraft release.',
        rawDetails: 'missing=${missingCompanions.join(',')}',
      );
    }

    return EudToolInspectionResult.ready(
      readyTool: EudToolInfo(
        pathSource: candidate.source,
        installationPath: installation.path,
        executablePath: executable.path,
        versionFilePath: versionFile.absolute.path,
        version: version,
        companionPaths: companionPaths,
      ),
    );
  }

  EudToolInspectionResult _failure({
    required String code,
    required String message,
    required String remediation,
    String? filePath,
    String? rawDetails,
  }) {
    return EudToolInspectionResult.failure(
      diagnostics: [
        EditorDiagnostic(
          code: code,
          message: message,
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.compile,
          filePath: filePath,
          remediation: remediation,
          rawDetails: rawDetails,
        ),
      ],
    );
  }

  String _joinRelative(String root, String relativePath) {
    return relativePath
        .split('/')
        .fold(
          root,
          (current, part) => '$current${Platform.pathSeparator}$part',
        );
  }

  String _basename(String path) {
    return path.split(RegExp(r'[\\/]')).where((part) => part.isNotEmpty).last;
  }
}
