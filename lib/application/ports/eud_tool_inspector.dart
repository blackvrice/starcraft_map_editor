import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class EudToolDiagnosticCodes {
  static const platformUnsupported = 'EUD_TOOL_PLATFORM_UNSUPPORTED';
  static const pathNotConfigured = 'EUD_TOOL_PATH_NOT_CONFIGURED';
  static const pathInvalid = 'EUD_TOOL_PATH_INVALID';
  static const executableMissing = 'EUD_TOOL_EXECUTABLE_MISSING';
  static const versionMissing = 'EUD_TOOL_VERSION_MISSING';
  static const versionInvalid = 'EUD_TOOL_VERSION_INVALID';
  static const versionUnsupported = 'EUD_TOOL_VERSION_UNSUPPORTED';
  static const companionMissing = 'EUD_TOOL_COMPANION_MISSING';
  static const inspectionFailed = 'EUD_TOOL_INSPECTION_FAILED';
}

enum EudToolPathSource { projectProfile, userSettings, bundled }

final class EudToolPathCandidate {
  EudToolPathCandidate({required String path, required this.source})
    : path = path.trim() {
    if (this.path.isEmpty) {
      throw ArgumentError.value(
        path,
        'path',
        'The tool path must not be blank.',
      );
    }
  }

  final String path;
  final EudToolPathSource source;
}

final class EudToolInspectionRequest {
  const EudToolInspectionRequest({
    this.projectProfilePath,
    this.userSettingsPath,
    this.bundledPath,
  });

  final String? projectProfilePath;
  final String? userSettingsPath;
  final String? bundledPath;

  EudToolPathCandidate? get selectedCandidate {
    final projectProfilePath = _nonBlank(this.projectProfilePath);
    if (projectProfilePath != null) {
      return EudToolPathCandidate(
        path: projectProfilePath,
        source: EudToolPathSource.projectProfile,
      );
    }

    final userSettingsPath = _nonBlank(this.userSettingsPath);
    if (userSettingsPath != null) {
      return EudToolPathCandidate(
        path: userSettingsPath,
        source: EudToolPathSource.userSettings,
      );
    }

    final bundledPath = _nonBlank(this.bundledPath);
    if (bundledPath != null) {
      return EudToolPathCandidate(
        path: bundledPath,
        source: EudToolPathSource.bundled,
      );
    }

    return null;
  }
}

final class EudToolVersion implements Comparable<EudToolVersion> {
  EudToolVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.revision,
  }) {
    for (final component in [major, minor, patch, revision]) {
      if (component < 0 || component > 0xffff) {
        throw RangeError.range(component, 0, 0xffff, 'versionComponent');
      }
    }
  }

  factory EudToolVersion.parse(String value) {
    final version = tryParse(value);
    if (version == null) {
      throw FormatException('Invalid four-component euddraft version.', value);
    }
    return version;
  }

  static EudToolVersion? tryParse(String value) {
    final match = RegExp(
      r'^([0-9]{1,5})\.([0-9]{1,5})\.([0-9]{1,5})\.([0-9]{1,5})$',
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }

    final components = [
      for (var index = 1; index <= 4; index++) int.parse(match.group(index)!),
    ];
    if (components.any((component) => component > 0xffff)) {
      return null;
    }
    return EudToolVersion(
      major: components[0],
      minor: components[1],
      patch: components[2],
      revision: components[3],
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int revision;

  @override
  int compareTo(EudToolVersion other) {
    final left = [major, minor, patch, revision];
    final right = [other.major, other.minor, other.patch, other.revision];
    for (var index = 0; index < left.length; index++) {
      final comparison = left[index].compareTo(right[index]);
      if (comparison != 0) {
        return comparison;
      }
    }
    return 0;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EudToolVersion &&
            major == other.major &&
            minor == other.minor &&
            patch == other.patch &&
            revision == other.revision;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, revision);

  @override
  String toString() => '$major.$minor.$patch.$revision';
}

final class EudToolInfo {
  EudToolInfo({
    required this.pathSource,
    required String installationPath,
    required String executablePath,
    required String versionFilePath,
    required this.version,
    required Iterable<String> companionPaths,
  }) : installationPath = _requireNonBlank(
         installationPath,
         'installationPath',
       ),
       executablePath = _requireNonBlank(executablePath, 'executablePath'),
       versionFilePath = _requireNonBlank(versionFilePath, 'versionFilePath'),
       companionPaths = List.unmodifiable(companionPaths);

  final EudToolPathSource pathSource;
  final String installationPath;
  final String executablePath;
  final String versionFilePath;
  final EudToolVersion version;
  final List<String> companionPaths;
}

final class EudToolInspectionResult {
  EudToolInspectionResult.ready({
    required EudToolInfo readyTool,
    Iterable<EditorDiagnostic> diagnostics = const [],
  }) : tool = readyTool,
       diagnostics = List.unmodifiable(diagnostics) {
    if (this.diagnostics.any((diagnostic) => diagnostic.blocksOperation)) {
      throw ArgumentError.value(
        diagnostics,
        'diagnostics',
        'A ready tool inspection cannot contain blocking diagnostics.',
      );
    }
  }

  EudToolInspectionResult.failure({
    required Iterable<EditorDiagnostic> diagnostics,
  }) : tool = null,
       diagnostics = List.unmodifiable(diagnostics) {
    if (!this.diagnostics.any((diagnostic) => diagnostic.blocksOperation)) {
      throw ArgumentError.value(
        diagnostics,
        'diagnostics',
        'A failed tool inspection requires a blocking diagnostic.',
      );
    }
  }

  final EudToolInfo? tool;
  final List<EditorDiagnostic> diagnostics;

  bool get isReady =>
      tool != null &&
      !diagnostics.any((diagnostic) => diagnostic.blocksOperation);
}

abstract interface class EudToolInspector {
  Future<EudToolInspectionResult> inspect(EudToolInspectionRequest request);
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _requireNonBlank(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'The path must not be blank.');
  }
  return trimmed;
}
