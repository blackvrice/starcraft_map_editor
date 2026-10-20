import 'dart:typed_data';

import '../raw_chk_document.dart';
import 'chk_trigger_editor.dart';

/// Strict read-only validation for operations that must understand every slot.
/// Unlike in-place edits, opaque/reserved bytes cannot be assumed harmless.
abstract final class ChkTriggerPortability {
  static void requireCanonical(
    ChkTrigger record,
    RawChkDocument document, {
    String diagnosticPrefix = 'TRIGGER',
  }) {
    final flags = ByteData.sublistView(
      Uint8List.fromList(record.bytes),
    ).getUint32(2368, Endian.little);
    if (flags & ~8 != 0 ||
        Iterable<int>.generate(28).any(
          (i) =>
              record.bytes[2372 + i] > 1 ||
              (!TriggerOpcodes.owners.containsKey(i) &&
                  record.bytes[2372 + i] != 0),
        )) {
      throw StateError('${diagnosticPrefix}_RAW_TRIGGER');
    }
    if (record.briefing) {
      final marker = Uint8List(320)..[15] = 13;
      if (!_equal(record.bytes.sublist(0, 320), marker)) {
        throw StateError('${diagnosticPrefix}_RAW_BRIEFING');
      }
    }
    for (final action in record.briefing ? [true] : [false, true]) {
      for (var i = 0; i < (action ? 64 : 16); i++) {
        final slot = record.slot(action, i);
        if (slot.every((b) => b == 0)) continue;
        if (!ChkTrigger.editable(action, slot, briefing: record.briefing)) {
          throw StateError('${diagnosticPrefix}_RAW_TRIGGER');
        }
        final op = TriggerOpcodes.find(
          action,
          ChkTrigger.type(action, slot),
          briefing: record.briefing,
        )!;
        final canonical = ChkTrigger.makeSlot(
          action,
          op,
          {for (final a in op.arguments) a.name: ChkTrigger.argument(slot, a)},
          document,
          briefing: record.briefing,
        );
        final flagAt = action ? 28 : 17;
        canonical[flagAt] |= slot[flagAt] & 2;
        if (!_equal(canonical, slot)) {
          throw StateError('${diagnosticPrefix}_RAW_TRIGGER');
        }
      }
    }
  }

  static bool _equal(List<int> a, List<int> b) =>
      a.length == b.length &&
      Iterable.generate(a.length).every((i) => a[i] == b[i]);
}
