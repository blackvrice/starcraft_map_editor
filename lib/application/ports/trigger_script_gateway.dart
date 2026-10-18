import '../../domain/chk/raw_chk_document.dart';
import '../../domain/triggers/trigger_script.dart';

final class TriggerScriptAnalysis {
  const TriggerScriptAnalysis({this.program, this.generated, this.diagnostic});
  final TriggerScriptProgram? program;
  final String? generated;
  final TriggerScriptDiagnostic? diagnostic;
  bool get isSuccess =>
      program != null && generated != null && diagnostic == null;
}

abstract interface class TriggerScriptGateway {
  Future<TriggerScriptAnalysis> analyze({
    required String operationId,
    required RawChkDocument document,
    required TriggerScriptLanguage language,
    String? source,
    TriggerScriptLanguage? target,
  });
  void cancel(String operationId);
}

final class TriggerScriptFile {
  const TriggerScriptFile(this.path, this.text, this.language);
  final String path, text;
  final TriggerScriptLanguage language;
}

abstract interface class TriggerScriptFiles {
  Future<TriggerScriptFile?> open();
  Future<String?> saveNew(String text, TriggerScriptLanguage language);
}
