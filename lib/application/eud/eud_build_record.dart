import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/eud_tool_inspector.dart';

enum EudBuildRecordStatus { running, succeeded, failed, cancelled }

enum EudBuildLogChannel { stdout, stderr }

final class EudBuildLogEntry {
  EudBuildLogEntry({
    required this.channel,
    required this.text,
    required DateTime capturedAt,
  }) : capturedAt = capturedAt.toUtc();

  final EudBuildLogChannel channel;
  final String text;
  final DateTime capturedAt;
}

final class EudBuildRecord {
  EudBuildRecord._({
    required String buildId,
    required this.status,
    required this.toolVersion,
    required DateTime startedAt,
    required DateTime? completedAt,
    required this.exitCode,
    required Iterable<EudBuildLogEntry> logEntries,
    required Iterable<EditorDiagnostic> diagnostics,
  }) : buildId = _requireNonBlank(buildId, 'buildId'),
       startedAt = startedAt.toUtc(),
       completedAt = completedAt?.toUtc(),
       logEntries = List.unmodifiable(logEntries),
       diagnostics = List.unmodifiable(diagnostics) {
    final completedAt = this.completedAt;
    if (status == EudBuildRecordStatus.running) {
      if (completedAt != null || exitCode != null) {
        throw ArgumentError(
          'A running EUD build record cannot have a completion result.',
        );
      }
    } else {
      if (completedAt == null) {
        throw ArgumentError(
          'A terminal EUD build record requires a completion time.',
        );
      }
      if (completedAt.isBefore(this.startedAt)) {
        throw ArgumentError.value(
          completedAt,
          'completedAt',
          'The completion time cannot precede the start time.',
        );
      }
    }
    if (status == EudBuildRecordStatus.succeeded && exitCode != 0) {
      throw ArgumentError.value(
        exitCode,
        'exitCode',
        'A successful EUD build record requires exit code 0.',
      );
    }
  }

  factory EudBuildRecord.running({
    required String buildId,
    required EudToolVersion toolVersion,
    required DateTime startedAt,
  }) {
    return EudBuildRecord._(
      buildId: buildId,
      status: EudBuildRecordStatus.running,
      toolVersion: toolVersion,
      startedAt: startedAt,
      completedAt: null,
      exitCode: null,
      logEntries: const [],
      diagnostics: const [],
    );
  }

  final String buildId;
  final EudBuildRecordStatus status;
  final EudToolVersion toolVersion;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? exitCode;
  final List<EudBuildLogEntry> logEntries;
  final List<EditorDiagnostic> diagnostics;

  bool get isTerminal => status != EudBuildRecordStatus.running;

  Duration? get duration {
    return completedAt?.difference(startedAt);
  }

  List<String> get stdoutLines => List.unmodifiable([
    for (final entry in logEntries)
      if (entry.channel == EudBuildLogChannel.stdout) entry.text,
  ]);

  List<String> get stderrLines => List.unmodifiable([
    for (final entry in logEntries)
      if (entry.channel == EudBuildLogChannel.stderr) entry.text,
  ]);

  EudBuildRecord withToolVersion(EudToolVersion toolVersion) {
    _requireRunning();
    return _copy(toolVersion: toolVersion);
  }

  EudBuildRecord appendLog({
    required EudBuildLogChannel channel,
    required String text,
    required DateTime capturedAt,
  }) {
    _requireRunning();
    return _copy(
      logEntries: [
        ...logEntries,
        EudBuildLogEntry(channel: channel, text: text, capturedAt: capturedAt),
      ],
    );
  }

  EudBuildRecord appendDiagnostic(EditorDiagnostic diagnostic) {
    _requireRunning();
    return _copy(diagnostics: [...diagnostics, diagnostic]);
  }

  EudBuildRecord complete({
    required EudBuildRecordStatus status,
    required DateTime completedAt,
    int? exitCode,
    EditorDiagnostic? diagnostic,
  }) {
    _requireRunning();
    if (status == EudBuildRecordStatus.running) {
      throw ArgumentError.value(
        status,
        'status',
        'A completed EUD build record requires a terminal status.',
      );
    }
    return EudBuildRecord._(
      buildId: buildId,
      status: status,
      toolVersion: toolVersion,
      startedAt: startedAt,
      completedAt: completedAt,
      exitCode: exitCode,
      logEntries: logEntries,
      diagnostics: [...diagnostics, ?diagnostic],
    );
  }

  EudBuildRecord _copy({
    EudToolVersion? toolVersion,
    Iterable<EudBuildLogEntry>? logEntries,
    Iterable<EditorDiagnostic>? diagnostics,
  }) {
    return EudBuildRecord._(
      buildId: buildId,
      status: status,
      toolVersion: toolVersion ?? this.toolVersion,
      startedAt: startedAt,
      completedAt: completedAt,
      exitCode: exitCode,
      logEntries: logEntries ?? this.logEntries,
      diagnostics: diagnostics ?? this.diagnostics,
    );
  }

  void _requireRunning() {
    if (isTerminal) {
      throw StateError('Build $buildId has already completed.');
    }
  }
}

String _requireNonBlank(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'The value must not be blank.');
  }
  return trimmed;
}
