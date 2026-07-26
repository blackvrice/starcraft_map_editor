import '../../domain/diagnostics/editor_diagnostic.dart';
import 'eud_tool_inspector.dart';

enum EudBuildEventKind {
  started,
  stdoutLine,
  stderrLine,
  diagnostic,
  cancelled,
  failed,
  succeeded,
}

final class EudBuildRequest {
  EudBuildRequest({
    required String buildId,
    required this.tool,
    required String settingsFilePath,
    required this.timeout,
    Map<String, String> environmentOverrides = const {},
  }) : buildId = _requireNonBlank(buildId, 'buildId'),
       settingsFilePath = _requireNonBlank(
         settingsFilePath,
         'settingsFilePath',
       ),
       environmentOverrides = Map.unmodifiable(environmentOverrides) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'The build timeout must be positive.',
      );
    }
    final normalizedEnvironmentNames = <String>{};
    for (final entry in this.environmentOverrides.entries) {
      if (entry.key.trim().isEmpty ||
          entry.key != entry.key.trim() ||
          entry.key.contains('=') ||
          entry.key.codeUnits.any(
            (codeUnit) => codeUnit < 0x20 || codeUnit == 0x7f,
          )) {
        throw ArgumentError.value(
          entry.key,
          'environmentOverrides',
          'Environment variable names must not have surrounding whitespace '
              'or contain "=" or control characters.',
        );
      }
      if (!normalizedEnvironmentNames.add(entry.key.toUpperCase())) {
        throw ArgumentError.value(
          entry.key,
          'environmentOverrides',
          'Environment variable names must be unique case-insensitively.',
        );
      }
      if (entry.value.contains('\u0000')) {
        throw ArgumentError.value(
          entry.value,
          'environmentOverrides',
          'Environment variable values cannot contain NUL.',
        );
      }
    }
  }

  final String buildId;
  final EudToolInfo tool;
  final String settingsFilePath;
  final Duration timeout;
  final Map<String, String> environmentOverrides;
}

final class EudBuildEvent {
  EudBuildEvent._({
    required this.kind,
    required String buildId,
    this.text,
    this.diagnostic,
    this.exitCode,
    this.toolVersion,
  }) : buildId = _requireNonBlank(buildId, 'buildId');

  factory EudBuildEvent.started({
    required String buildId,
    required EudToolVersion toolVersion,
  }) {
    return EudBuildEvent._(
      kind: EudBuildEventKind.started,
      buildId: buildId,
      toolVersion: toolVersion,
    );
  }

  factory EudBuildEvent.stdoutLine({
    required String buildId,
    required String text,
  }) {
    return EudBuildEvent._(
      kind: EudBuildEventKind.stdoutLine,
      buildId: buildId,
      text: text,
    );
  }

  factory EudBuildEvent.stderrLine({
    required String buildId,
    required String text,
  }) {
    return EudBuildEvent._(
      kind: EudBuildEventKind.stderrLine,
      buildId: buildId,
      text: text,
    );
  }

  factory EudBuildEvent.diagnostic({
    required String buildId,
    required EditorDiagnostic diagnostic,
  }) {
    return EudBuildEvent._(
      kind: EudBuildEventKind.diagnostic,
      buildId: buildId,
      diagnostic: diagnostic,
    );
  }

  factory EudBuildEvent.cancelled({
    required String buildId,
    required EditorDiagnostic diagnostic,
    int? exitCode,
  }) {
    _requireBlockingDiagnostic(diagnostic, 'cancelled');
    return EudBuildEvent._(
      kind: EudBuildEventKind.cancelled,
      buildId: buildId,
      diagnostic: diagnostic,
      exitCode: exitCode,
    );
  }

  factory EudBuildEvent.failed({
    required String buildId,
    required EditorDiagnostic diagnostic,
    int? exitCode,
  }) {
    _requireBlockingDiagnostic(diagnostic, 'failed');
    return EudBuildEvent._(
      kind: EudBuildEventKind.failed,
      buildId: buildId,
      diagnostic: diagnostic,
      exitCode: exitCode,
    );
  }

  factory EudBuildEvent.succeeded({
    required String buildId,
    required int exitCode,
  }) {
    if (exitCode != 0) {
      throw ArgumentError.value(
        exitCode,
        'exitCode',
        'A successful build event requires exit code 0.',
      );
    }
    return EudBuildEvent._(
      kind: EudBuildEventKind.succeeded,
      buildId: buildId,
      exitCode: exitCode,
    );
  }

  final EudBuildEventKind kind;
  final String buildId;
  final String? text;
  final EditorDiagnostic? diagnostic;
  final int? exitCode;
  final EudToolVersion? toolVersion;

  bool get isTerminal =>
      kind == EudBuildEventKind.cancelled ||
      kind == EudBuildEventKind.failed ||
      kind == EudBuildEventKind.succeeded;
}

String _requireNonBlank(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'The value must not be blank.');
  }
  return trimmed;
}

void _requireBlockingDiagnostic(EditorDiagnostic diagnostic, String kind) {
  if (!diagnostic.blocksOperation) {
    throw ArgumentError.value(
      diagnostic,
      'diagnostic',
      'A $kind build event requires a blocking diagnostic.',
    );
  }
}
