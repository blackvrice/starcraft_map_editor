import '../diagnostics/editor_diagnostic.dart';
import 'raw_chk_document.dart';

class RawChkParseResult {
  RawChkParseResult.success(RawChkDocument parsedDocument)
    : document = parsedDocument,
      diagnostics = const [];

  RawChkParseResult.failure(EditorDiagnostic diagnostic)
    : document = null,
      diagnostics = List.unmodifiable([diagnostic]);

  final RawChkDocument? document;
  final List<EditorDiagnostic> diagnostics;

  bool get isSuccess => document != null && !hasBlockingDiagnostics;

  bool get hasBlockingDiagnostics =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);
}
