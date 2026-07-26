import '../ports/eud_compiler_gateway.dart';
import '../ports/eud_tool_inspector.dart';
import 'eud_environment.dart';

enum EudCompilerProfile {
  starcraftRemastered(
    id: 'scr-euddraft',
    game: 'StarCraft: Remastered',
    language: 'epScript',
    outputExtension: '.scx',
  );

  const EudCompilerProfile({
    required this.id,
    required this.game,
    required this.language,
    required this.outputExtension,
  });

  final String id;
  final String game;
  final String language;
  final String outputExtension;
}

final class EudBuildConfiguration {
  EudBuildConfiguration({
    required String baseMapPath,
    required String sourceRootPath,
    required String entrySourcePath,
    required String outputMapPath,
    this.compilerProfile = EudCompilerProfile.starcraftRemastered,
    String? compilerPathOverride,
    Map<String, String> compilerOptions = const {},
    Map<String, String> environmentOverrides = const {},
  }) : baseMapPath = _requireAbsoluteWindowsPath(baseMapPath, 'baseMapPath'),
       sourceRootPath = _requireAbsoluteWindowsPath(
         sourceRootPath,
         'sourceRootPath',
       ),
       entrySourcePath = _requireAbsoluteWindowsPath(
         entrySourcePath,
         'entrySourcePath',
       ),
       outputMapPath = _requireAbsoluteWindowsPath(
         outputMapPath,
         'outputMapPath',
       ),
       compilerPathOverride = _optionalAbsoluteWindowsPath(
         compilerPathOverride,
         'compilerPathOverride',
       ),
       compilerOptions = _copyCompilerOptions(compilerOptions),
       environmentOverrides = EudEnvironmentRules.copyAndValidate(
         environmentOverrides,
       ) {
    const mapExtensions = {'.scm', '.scx'};
    const sourceExtensions = {'.eps'};
    _requireExtension(this.baseMapPath, mapExtensions, 'baseMapPath');
    _requireExtension(
      this.entrySourcePath,
      sourceExtensions,
      'entrySourcePath',
    );
    _requireExtension(this.outputMapPath, {
      compilerProfile.outputExtension,
    }, 'outputMapPath');

    final normalizedBase = _normalizeWindowsPath(this.baseMapPath);
    final normalizedSourceRoot = _normalizeWindowsPath(this.sourceRootPath);
    final normalizedEntry = _normalizeWindowsPath(this.entrySourcePath);
    final normalizedOutput = _normalizeWindowsPath(this.outputMapPath);
    if (normalizedBase == normalizedOutput) {
      throw ArgumentError.value(
        outputMapPath,
        'outputMapPath',
        'The EUD output must not overwrite the base map.',
      );
    }
    if (!_isWithin(normalizedSourceRoot, normalizedEntry)) {
      throw ArgumentError.value(
        entrySourcePath,
        'entrySourcePath',
        'The entry source must be inside the configured source root.',
      );
    }
    if (_isSameOrWithin(normalizedSourceRoot, normalizedOutput)) {
      throw ArgumentError.value(
        outputMapPath,
        'outputMapPath',
        'Generated output must be outside the source tree.',
      );
    }
  }

  final String baseMapPath;
  final String sourceRootPath;
  final String entrySourcePath;
  final String outputMapPath;
  final EudCompilerProfile compilerProfile;
  final String? compilerPathOverride;
  final Map<String, String> compilerOptions;
  final Map<String, String> environmentOverrides;

  EudToolInspectionRequest createToolInspectionRequest({
    String? userSettingsPath,
    String? bundledPath,
  }) {
    return EudToolInspectionRequest(
      projectProfilePath: compilerPathOverride,
      userSettingsPath: userSettingsPath,
      bundledPath: bundledPath,
    );
  }

  EudBuildRequest createCompilerRequest({
    required String buildId,
    required EudToolInfo tool,
    required String settingsFilePath,
    required Duration timeout,
  }) {
    return EudBuildRequest(
      buildId: buildId,
      tool: tool,
      settingsFilePath: settingsFilePath,
      timeout: timeout,
      environmentOverrides: environmentOverrides,
    );
  }
}

String _requireAbsoluteWindowsPath(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || value != trimmed || !_isAbsoluteWindowsPath(value)) {
    throw ArgumentError.value(
      value,
      name,
      'The path must be an absolute Windows drive or UNC path without '
      'surrounding whitespace.',
    );
  }
  _validatePathSegments(value, name);
  return value;
}

String? _optionalAbsoluteWindowsPath(String? value, String name) {
  if (value == null) {
    return null;
  }
  return _requireAbsoluteWindowsPath(value, name);
}

bool _isAbsoluteWindowsPath(String path) {
  if (path.startsWith(r'\\?\') || path.startsWith(r'\\.\')) {
    return false;
  }
  return RegExp(
    r'^(?:[a-zA-Z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|$))',
  ).hasMatch(path);
}

void _validatePathSegments(String path, String name) {
  final normalized = path.replaceAll('/', r'\');
  final isDrivePath = RegExp(r'^[a-zA-Z]:\\').hasMatch(normalized);
  final rootOffset = isDrivePath ? 3 : 2;
  final body = normalized.substring(rootOffset);
  final segments = body.split(RegExp(r'\\+'));
  for (final segment in segments) {
    if (segment.isEmpty) {
      continue;
    }
    if (segment == '.' ||
        segment == '..' ||
        segment.endsWith(' ') ||
        segment.endsWith('.') ||
        _isReservedWindowsName(segment) ||
        segment.contains(RegExp(r'[<>:"|?*]')) ||
        segment.codeUnits.any(
          (codeUnit) => codeUnit < 0x20 || codeUnit == 0x7f,
        )) {
      throw ArgumentError.value(
        path,
        name,
        'The path contains an unsafe or ambiguous Windows segment.',
      );
    }
  }
}

bool _isReservedWindowsName(String segment) {
  final basename = segment.split('.').first.toUpperCase();
  return const {'CON', 'PRN', 'AUX', 'NUL'}.contains(basename) ||
      RegExp(r'^(?:COM|LPT)[1-9]$').hasMatch(basename);
}

void _requireExtension(
  String path,
  Set<String> allowedExtensions,
  String name,
) {
  final lowerPath = path.toLowerCase();
  if (!allowedExtensions.any(lowerPath.endsWith)) {
    throw ArgumentError.value(
      path,
      name,
      'The path must use one of: ${allowedExtensions.join(', ')}.',
    );
  }
}

String _normalizeWindowsPath(String path) {
  var normalized = path.trim().replaceAll('/', r'\');
  if (normalized.startsWith(r'\\')) {
    normalized =
        r'\\' + normalized.substring(2).replaceAll(RegExp(r'\\+'), r'\');
  } else {
    normalized = normalized.replaceAll(RegExp(r'\\+'), r'\');
  }
  while (normalized.length > 3 && normalized.endsWith(r'\')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized.toLowerCase();
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

Map<String, String> _copyCompilerOptions(Map<String, String> options) {
  final copied = Map<String, String>.of(options);
  for (final entry in copied.entries) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,63}$').hasMatch(entry.key)) {
      throw ArgumentError.value(
        entry.key,
        'compilerOptions',
        'Compiler option names must use 1-64 ASCII letters, digits, ".", '
            '"_", or "-".',
      );
    }
    if (entry.value.contains('\u0000') ||
        entry.value.contains('\r') ||
        entry.value.contains('\n')) {
      throw ArgumentError.value(
        entry.value,
        'compilerOptions',
        'Compiler option values cannot contain NUL or line breaks.',
      );
    }
    if (const {'input', 'output'}.contains(entry.key)) {
      throw ArgumentError.value(
        entry.key,
        'compilerOptions',
        'The input and output manifest keys are managed by the safe build '
            'pipeline.',
      );
    }
  }
  return Map.unmodifiable(copied);
}
