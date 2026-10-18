import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import '../chk/raw_chk_document.dart';
import '../chk/raw_chk_encoder.dart';
import '../chk/typed/chk_trigger_editor.dart';
import 'trigger_script_syntax.dart';
export 'trigger_script_syntax.dart';

final class TriggerScriptRecord {
  const TriggerScriptRecord(this.origin, this.record);
  final int? origin;
  final ChkTrigger record;
}

final class TriggerScriptProgram {
  TriggerScriptProgram(List<TriggerScriptRecord> records, this.opaqueDeletions)
    : records = List.unmodifiable(records);
  final List<TriggerScriptRecord> records;
  final int opaqueDeletions;
  List<ChkTrigger> get triggers =>
      List.unmodifiable(records.map((r) => r.record));
  bool sameMeaning(TriggerScriptProgram other) {
    if (records.length != other.records.length ||
        opaqueDeletions != other.opaqueDeletions) {
      return false;
    }
    for (var i = 0; i < records.length; i++) {
      final a = records[i], b = other.records[i];
      if (a.origin != b.origin) return false;
      for (var k = 0; k < 2400; k++) {
        if (a.record.bytes[k] != b.record.bytes[k]) return false;
      }
    }
    return true;
  }
}

/// A source reference is valid only against the exact CHK snapshot. Unknown
/// slots never become byte literals that a script could inject into another map.
final class TriggerScriptSnapshot {
  TriggerScriptSnapshot(this.document) {
    if (document.sections.fold<int>(0, (n, s) => n + 8 + s.payload.length) >
        64 * 1024 * 1024) {
      throw const TriggerScriptDiagnostic('SCRIPT_MAP_SIZE', 0);
    }
    final triggers = ChkTriggers.read(document);
    if (triggers.records.length > maximumRecords) {
      throw const TriggerScriptDiagnostic('SCRIPT_RECORD_BUDGET', 0);
    }
    original = triggers.records;
    fingerprint = sha256
        .convert(const RawChkEncoder().encode(document))
        .toString();
  }
  static const version = 1;
  static const maximumRecords = 512;
  final RawChkDocument document;
  late final List<ChkTrigger> original;
  late final String fingerprint;
  TriggerScriptProgram get initial => TriggerScriptProgram([
    for (var i = 0; i < original.length; i++)
      TriggerScriptRecord(i, original[i]),
  ], 0);

  static final conditionNames = _names(false);
  static final actionNames = _names(true);
  static Map<String, TriggerOpcode> _names(bool action) => Map.unmodifiable({
    for (final op
        in action ? TriggerOpcodes.actions : TriggerOpcodes.conditions)
      '${action ? "Action" : "Condition"}${op.name.replaceAll(RegExp(r'\([^)]*\)'), '').split(RegExp('[^A-Za-z0-9]+')).where((s) => s.isNotEmpty).map((s) => s[0].toUpperCase() + s.substring(1)).join()}':
          op,
  });
  static String nameOf(bool action, TriggerOpcode op) =>
      (action ? actionNames : conditionNames).entries
          .singleWhere((e) => e.value == op)
          .key;

  bool portable(bool action, List<int> slot) {
    if (!ChkTrigger.editable(action, slot)) return false;
    final op = TriggerOpcodes.find(action, ChkTrigger.type(action, slot))!;
    try {
      ChkTrigger.makeSlot(
        action,
        op,
        {for (final a in op.arguments) a.name: ChkTrigger.argument(slot, a)},
        document,
        original: slot,
      );
      return true;
    } on FormatException {
      return false;
    }
  }

  String format(TriggerScriptProgram program, TriggerScriptLanguage language) {
    final end = language == TriggerScriptLanguage.epScript ? ';' : '';
    final out = StringBuffer(
      '${language.comment} Map trigger declarations v$version; canonical output\n'
      'MapScript($version, "$fingerprint")$end\n',
    );
    for (final model in program.records) {
      final record = model.record;
      out.writeln('\nMapTrigger(');
      out.writeln(
        '    ${model.origin == null ? "New()" : "Source(${model.origin})"},',
      );
      out.writeln(
        '    Owners(${TriggerOpcodes.owners.keys.where((i) => record.bytes[2372 + i] != 0).join(", ")}),',
      );
      out.writeln('    Enabled(${language.boolean(record.enabled)}),');
      for (final action in [false, true]) {
        out.writeln('    ${action ? "Actions" : "Conditions"}(');
        final slots = <String>[];
        for (var i = 0; i < (action ? 64 : 16); i++) {
          final slot = record.slot(action, i);
          if (slot.every((b) => b == 0)) continue;
          if (!portable(action, slot)) {
            slots.add('        Raw${action ? "Action" : "Condition"}($i)');
          } else {
            final op = TriggerOpcodes.find(
              action,
              ChkTrigger.type(action, slot),
            )!;
            final args = [
              for (final a in op.arguments) ChkTrigger.argument(slot, a),
            ];
            slots.add(
              '        ${nameOf(action, op)}($i, ${language.boolean(slot[action ? 28 : 17] & 2 == 0)}'
              '${args.isEmpty ? "" : ", ${args.join(", ")}"})',
            );
          }
        }
        out.writeln(slots.join(',\n'));
        out.writeln('    )${action ? "" : ","}');
      }
      out.writeln(')$end');
    }
    final result = out.toString();
    if (result.length > TriggerScriptSyntax.maximumCharacters) {
      throw const TriggerScriptDiagnostic('SCRIPT_SIZE', 0);
    }
    return result;
  }

  TriggerScriptProgram parse(String text, TriggerScriptLanguage language) {
    final calls = TriggerScriptSyntax(text, language).parse();
    if (calls.isEmpty) throw const TriggerScriptDiagnostic('SCRIPT_HEADER', 0);
    final header = calls.first;
    if (header.name != 'MapScript' ||
        header.arguments.length != 2 ||
        header.arguments[0] != version ||
        header.arguments[1] != fingerprint) {
      throw TriggerScriptDiagnostic('SCRIPT_SNAPSHOT', header.offset);
    }
    if (calls.length - 1 > maximumRecords) {
      throw const TriggerScriptDiagnostic('SCRIPT_RECORD_BUDGET', 0);
    }
    final records = <TriggerScriptRecord>[];
    final used = <int>{}, rawKept = <(int, bool, int)>{};
    for (final call in calls.skip(1)) {
      _shape(call, 'MapTrigger', 5);
      final source = _call(call.arguments[0], call);
      final int? origin;
      ChkTrigger base;
      if (source.name == 'New') {
        _shape(source, 'New', 0);
        origin = null;
        base = ChkTrigger(List.filled(2400, 0));
      } else {
        _shape(source, 'Source', 1);
        origin = _integer(source.arguments.single, source, original.length - 1);
        if (!used.add(origin)) _error('SCRIPT_DUPLICATE_SOURCE', source);
        base = original[origin];
      }
      final owners = _call(call.arguments[1], call);
      if (owners.name != 'Owners') _error('SCRIPT_OWNERS', owners);
      final selectedOwners = <int>{};
      for (final owner in owners.arguments) {
        final id = _integer(owner, owners, 27);
        if (!TriggerOpcodes.owners.containsKey(id) || !selectedOwners.add(id)) {
          _error('SCRIPT_OWNER', owners);
        }
      }
      // Assemble one record buffer rather than copying 2400 bytes for every
      // empty slot. Slot arguments still pass through the existing validator.
      final bytes = Uint8List.fromList(base.bytes)..fillRange(0, 2368, 0);
      for (final id in TriggerOpcodes.owners.keys) {
        if ((base.bytes[2372 + id] != 0) != selectedOwners.contains(id)) {
          bytes[2372 + id] = selectedOwners.contains(id) ? 1 : 0;
        }
      }
      final enabled = _call(call.arguments[2], call);
      _shape(enabled, 'Enabled', 1);
      bytes[2368] = _boolean(enabled.arguments.single, enabled)
          ? bytes[2368] & ~8
          : bytes[2368] | 8;
      for (final action in [false, true]) {
        final group = _call(call.arguments[action ? 4 : 3], call);
        if (group.name != (action ? 'Actions' : 'Conditions') ||
            group.arguments.length > (action ? 64 : 16)) {
          _error('SCRIPT_SLOTS', group);
        }
        final occupied = <int>{};
        for (final value in group.arguments) {
          final slotCall = _call(value, group);
          if (slotCall.arguments.isEmpty) {
            _error('SCRIPT_SLOT_ARGUMENTS', slotCall);
          }
          final index = _integer(
            slotCall.arguments.first,
            slotCall,
            action ? 63 : 15,
          );
          if (!occupied.add(index)) _error('SCRIPT_DUPLICATE_SLOT', slotCall);
          final old = base.slot(action, index);
          final offset = (action ? 320 : 0) + index * (action ? 32 : 20);
          final rawName = 'Raw${action ? "Action" : "Condition"}';
          if (slotCall.name == rawName) {
            _shape(slotCall, rawName, 1);
            if (origin == null ||
                old.every((b) => b == 0) ||
                portable(action, old)) {
              _error('SCRIPT_RAW_REFERENCE', slotCall);
            }
            bytes.setRange(offset, offset + old.length, old);
            rawKept.add((origin, action, index));
            continue;
          }
          final opcode = (action ? actionNames : conditionNames)[slotCall.name];
          if (opcode == null) _error('SCRIPT_UNSUPPORTED_API', slotCall);
          if (slotCall.arguments.length != opcode.arguments.length + 2) {
            _error('SCRIPT_SLOT_ARGUMENTS', slotCall);
          }
          final active = _boolean(slotCall.arguments[1], slotCall);
          final args = <String, int>{};
          for (var a = 0; a < opcode.arguments.length; a++) {
            args[opcode.arguments[a].name] = _integer(
              slotCall.arguments[a + 2],
              slotCall,
              0xffffffff,
            );
          }
          try {
            final slot = ChkTrigger.makeSlot(
              action,
              opcode,
              args,
              document,
              original:
                  portable(action, old) &&
                      ChkTrigger.type(action, old) == opcode.id
                  ? old
                  : null,
            );
            final flags = action ? 28 : 17;
            slot[flags] = active ? slot[flags] & ~2 : slot[flags] | 2;
            bytes.setRange(offset, offset + slot.length, slot);
          } on FormatException catch (e) {
            _error('SCRIPT_ARGUMENT', slotCall, e.message);
          }
        }
      }
      records.add(TriggerScriptRecord(origin, ChkTrigger(bytes)));
    }
    var opaque = 0;
    for (var r = 0; r < original.length; r++) {
      if (!used.contains(r)) {
        opaque++; // Entire record deletion always needs consent.
      }
      for (final action in [false, true]) {
        for (var s = 0; s < (action ? 64 : 16); s++) {
          final slot = original[r].slot(action, s);
          if (slot.any((b) => b != 0) &&
              !portable(action, slot) &&
              !rawKept.contains((r, action, s))) {
            opaque++;
          }
        }
      }
    }
    return TriggerScriptProgram(records, opaque);
  }

  static TriggerScriptCall _call(Object value, TriggerScriptCall parent) {
    if (value is! TriggerScriptCall) _error('SCRIPT_EXPECT_CALL', parent);
    return value;
  }

  static int _integer(Object value, TriggerScriptCall call, int maximum) {
    if (value is! int || value < 0 || value > maximum) {
      _error('SCRIPT_EXPECT_INTEGER', call);
    }
    return value;
  }

  static bool _boolean(Object value, TriggerScriptCall call) {
    if (value is! bool) _error('SCRIPT_EXPECT_BOOLEAN', call);
    return value;
  }

  static void _shape(TriggerScriptCall call, String name, int count) {
    if (call.name != name || call.arguments.length != count) {
      _error('SCRIPT_SHAPE', call, name);
    }
  }

  static Never _error(
    String code,
    TriggerScriptCall call, [
    String detail = '',
  ]) => throw TriggerScriptDiagnostic(code, call.offset, detail);
}
