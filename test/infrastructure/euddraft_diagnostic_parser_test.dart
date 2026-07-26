import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_diagnostic_parser.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/euddraft_diagnostic_parser.dart';

void main() {
  const parser = EuddraftDiagnosticParser();

  test('converts an official epScript error line into a source diagnostic', () {
    const rawLine =
        r'[Error 7041] Module "C:\Project\EUD Source\main.eps" '
        'Line 27 : Undefined function SpawnBoss';

    final diagnostic = parser.parseLine(
      channel: EudCompilerOutputChannel.stderr,
      text: rawLine,
    );

    expect(diagnostic, isNotNull);
    expect(diagnostic!.code, 'EUD_EPSCRIPT_ERROR_7041');
    expect(diagnostic.message, 'Undefined function SpawnBoss');
    expect(diagnostic.severity, DiagnosticSeverity.error);
    expect(diagnostic.stage, DiagnosticStage.compile);
    expect(diagnostic.filePath, r'C:\Project\EUD Source\main.eps');
    expect(diagnostic.sourceLine, 27);
    expect(diagnostic.sourceColumn, isNull);
    expect(diagnostic.rawDetails, rawLine);
  });

  test('normalizes negative epScript compiler codes', () {
    final diagnostic = parser.parseLine(
      channel: EudCompilerOutputChannel.stderr,
      text: '[Error -2] Module "메인.eps" Line 3 : General syntax error',
    );

    expect(diagnostic?.code, 'EUD_EPSCRIPT_ERROR_NEG_2');
    expect(diagnostic?.filePath, '메인.eps');
    expect(diagnostic?.sourceLine, 3);
  });

  test('does not interpret matching text written to stdout', () {
    final diagnostic = parser.parseLine(
      channel: EudCompilerOutputChannel.stdout,
      text: '[Error 7041] Module "main.eps" Line 27 : User log text',
    );

    expect(diagnostic, isNull);
  });

  test('leaves unknown or incomplete stderr lines unparsed', () {
    for (final line in [
      'Traceback (most recent call last):',
      'Error occurred : parser failed',
      '[Error 7041] Module "main.eps" Line 0 : Invalid line',
      '[Error 7041] Module "main.eps" Line 9999999999 : Invalid line',
      '[Error 9999999999] Module "main.eps" Line 27 : Invalid code',
      '[Error 7041] Module "main.eps" Line 27 : ',
    ]) {
      expect(
        parser.parseLine(channel: EudCompilerOutputChannel.stderr, text: line),
        isNull,
        reason: line,
      );
    }
  });
}
