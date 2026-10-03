import 'package:flutter/widgets.dart';

import '../../domain/diagnostics/editor_diagnostic.dart';
import 'l10n.dart';

part 'editor_messages.g.dart';

String localizedDiagnosticMessage(
  AppLocalizations l10n,
  EditorDiagnostic diagnostic,
) {
  if (diagnostic.messageId != null) {
    return resolveEditorMessage(
          l10n,
          diagnostic.messageId,
          diagnostic.messageArguments,
        ) ??
        diagnostic.message;
  }
  // A compiler's source diagnostic is verbatim executable-tool output.
  if (diagnostic.code.startsWith('EUD_EPSCRIPT_ERROR_')) {
    return diagnostic.message;
  }
  return translateEditorText(l10n, diagnostic.message);
}

String? localizedDiagnosticRemediation(
  AppLocalizations l10n,
  EditorDiagnostic diagnostic,
) {
  if (diagnostic.remediationId != null) {
    return resolveEditorMessage(
          l10n,
          diagnostic.remediationId,
          diagnostic.remediationArguments,
        ) ??
        diagnostic.remediation;
  }
  return diagnostic.remediation == null
      ? null
      : translateEditorText(l10n, diagnostic.remediation!);
}

extension EditorMessageLocalization on BuildContext {
  String diagnosticMessage(EditorDiagnostic diagnostic) =>
      localizedDiagnosticMessage(l10n, diagnostic);

  String? diagnosticRemediation(EditorDiagnostic diagnostic) =>
      localizedDiagnosticRemediation(l10n, diagnostic);

  /// Only for editor-owned labels/validation text, never user data or raw logs.
  String localizeEditorText(String text) => translateEditorText(l10n, text);
}

String translateEditorText(
  AppLocalizations l10n,
  String text, [
  int depth = 0,
]) {
  if (l10n.localeName == 'en' || depth > 4) return text;
  final exact = _exactMessages[text];
  if (exact != null) {
    return resolveEditorMessage(l10n, exact, const []) ?? text;
  }
  for (final prefix in [
    'FormatException: ',
    'Bad state: ',
    'Invalid argument(s): ',
  ]) {
    if (text.startsWith(prefix)) {
      final original = text.substring(prefix.length);
      final translated = translateEditorText(l10n, original, depth + 1);
      return translated == original ? text : translated;
    }
  }
  for (final entry in _legacyTemplates) {
    final match = entry.pattern.firstMatch(text);
    if (match == null) continue;
    return resolveEditorMessage(l10n, entry.id, [
          for (var i = 1; i <= match.groupCount; i++)
            translateEditorText(l10n, match.group(i)!, depth + 1),
        ]) ??
        text;
  }
  return text;
}
