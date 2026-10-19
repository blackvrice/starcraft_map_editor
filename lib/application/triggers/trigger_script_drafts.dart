import 'dart:async';
import 'dart:convert';

import '../../domain/chk/chk.dart';
import '../../domain/triggers/trigger_script.dart';

final class TriggerScriptDraft {
  const TriggerScriptDraft(this.text, this.language);
  final String text;
  final TriggerScriptLanguage language;
  Map<String, Object> toJson() => {'text': text, 'language': language.name};
  factory TriggerScriptDraft.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String;
    if (text.length > TriggerScriptRecovery.maximumDraftCharacters) {
      throw const FormatException('SCRIPT_SIZE');
    }
    return TriggerScriptDraft(
      text,
      TriggerScriptLanguage.values.byName(json['language'] as String),
    );
  }
}

/// Document-owned text, independent of the lifetime of the script dialog.
/// The baseline is retained even after map edits; recovery never rebases code.
final class TriggerScriptRecovery {
  TriggerScriptRecovery({
    required this.baseline,
    required this.current,
    required this.loadedText,
    required Iterable<TriggerScriptDraft> history,
  }) : history = List.unmodifiable(history) {
    if (this.history.length > 8 ||
        loadedText.length > maximumDraftCharacters ||
        [
          current,
          ...this.history,
        ].any((d) => d.text.length > maximumDraftCharacters)) {
      throw const FormatException('SCRIPT_RECOVERY_LIMIT');
    }
  }
  static const maximumDraftCharacters = 4 * 1024 * 1024;
  final RawChkDocument baseline;
  final TriggerScriptDraft current;
  final String loadedText;
  final List<TriggerScriptDraft> history;

  Map<String, Object> toJson() => {
    'baseline': base64Encode(const RawChkEncoder().encode(baseline)),
    'current': current.toJson(),
    'loadedText': loadedText,
    'history': history.map((d) => d.toJson()).toList(),
  };
  factory TriggerScriptRecovery.fromJson(Map<String, dynamic> json) {
    final bytes = base64Decode(json['baseline'] as String);
    if (bytes.length > 64 * 1024 * 1024) {
      throw const FormatException('SCRIPT_RECOVERY_LIMIT');
    }
    final result = const RawChkParser().parse(bytes);
    if (!result.isSuccess ||
        result.document!.sections.any((s) => s.isEuddraftProtectionMarker)) {
      throw const FormatException('SCRIPT_RECOVERY_BASELINE');
    }
    final history = json['history'] as List<dynamic>;
    if (history.length > 8) {
      throw const FormatException('SCRIPT_RECOVERY_LIMIT');
    }
    return TriggerScriptRecovery(
      baseline: result.document!,
      current: TriggerScriptDraft.fromJson(
        json['current'] as Map<String, dynamic>,
      ),
      loadedText: json['loadedText'] as String,
      history: history.map(
        (d) => TriggerScriptDraft.fromJson(d as Map<String, dynamic>),
      ),
    );
  }
}

final class TriggerScriptDraftWorkspace {
  TriggerScriptRecovery? value;
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  void update(TriggerScriptRecovery? next) {
    if (next == null && value == null) return;
    value = next;
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
