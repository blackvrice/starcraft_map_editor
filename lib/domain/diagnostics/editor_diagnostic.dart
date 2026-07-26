enum DiagnosticSeverity { info, warning, error, fatal }

enum DiagnosticStage {
  application,
  archive,
  parse,
  validate,
  edit,
  save,
  compile,
  launch,
}

class EditorDiagnostic {
  const EditorDiagnostic({
    required this.code,
    required this.message,
    required this.severity,
    required this.stage,
    this.filePath,
    this.sectionName,
    this.byteOffset,
    this.sourceLine,
    this.sourceColumn,
    this.remediation,
    this.rawDetails,
  });

  final String code;
  final String message;
  final DiagnosticSeverity severity;
  final DiagnosticStage stage;
  final String? filePath;
  final String? sectionName;
  final int? byteOffset;
  final int? sourceLine;
  final int? sourceColumn;
  final String? remediation;
  final String? rawDetails;

  bool get blocksOperation =>
      severity == DiagnosticSeverity.error ||
      severity == DiagnosticSeverity.fatal;
}
