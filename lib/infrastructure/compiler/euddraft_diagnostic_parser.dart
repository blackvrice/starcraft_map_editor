import '../../application/ports/eud_compiler_diagnostic_parser.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class EuddraftDiagnosticCodes {
  static const epScriptErrorPrefix = 'EUD_EPSCRIPT_ERROR_';
}

final class EuddraftDiagnosticParser implements EudCompilerDiagnosticParser {
  const EuddraftDiagnosticParser();

  static final RegExp _epScriptErrorPattern = RegExp(
    r'^\[Error (-?\d{1,10})\] Module "([^"]+)" '
    r'Line ([1-9]\d{0,9}) : (.+)$',
  );

  @override
  EditorDiagnostic? parseLine({
    required EudCompilerOutputChannel channel,
    required String text,
  }) {
    if (channel != EudCompilerOutputChannel.stderr) {
      return null;
    }

    final match = _epScriptErrorPattern.firstMatch(text.trim());
    if (match == null) {
      return null;
    }

    final compilerCode = int.tryParse(match.group(1)!);
    final filePath = match.group(2)!.trim();
    final sourceLine = int.tryParse(match.group(3)!);
    final message = match.group(4)!.trim();
    if (compilerCode == null ||
        compilerCode < -0x80000000 ||
        compilerCode > 0x7FFFFFFF ||
        filePath.isEmpty ||
        sourceLine == null ||
        sourceLine > 0x7FFFFFFF ||
        message.isEmpty) {
      return null;
    }

    final normalizedCode = compilerCode < 0
        ? 'NEG_${-compilerCode}'
        : '$compilerCode';
    return EditorDiagnostic(
      code: '${EuddraftDiagnosticCodes.epScriptErrorPrefix}$normalizedCode',
      message: message,
      severity: DiagnosticSeverity.error,
      stage: DiagnosticStage.compile,
      filePath: filePath,
      sourceLine: sourceLine,
      remediation: 'Open the reported epScript module and fix this line.',
      rawDetails: text,
    );
  }
}
