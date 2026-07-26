import '../../domain/diagnostics/editor_diagnostic.dart';

enum EudCompilerOutputChannel { stdout, stderr }

abstract interface class EudCompilerDiagnosticParser {
  const EudCompilerDiagnosticParser();

  EditorDiagnostic? parseLine({
    required EudCompilerOutputChannel channel,
    required String text,
  });
}

final class IgnoreEudCompilerDiagnostics
    implements EudCompilerDiagnosticParser {
  const IgnoreEudCompilerDiagnostics();

  @override
  EditorDiagnostic? parseLine({
    required EudCompilerOutputChannel channel,
    required String text,
  }) {
    return null;
  }
}
