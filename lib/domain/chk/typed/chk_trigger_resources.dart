import 'dart:convert';
import 'dart:typed_data';
import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_string_views.dart';
import 'chk_trigger_editor.dart';

/// Copy-on-write resource edits. Existing strings and unrelated bytes survive.
abstract final class ChkTriggerResources {
  static int? index(RawChkDocument doc, String name, int length) {
    final found = [
      for (var i = 0; i < doc.sections.length; i++)
        if (doc.sections[i].name == name) i,
    ];
    if (found.length > 1 ||
        (found.isNotEmpty &&
            doc.sections[found.single].payload.length != length)) {
      throw FormatException('Ambiguous or malformed $name section.');
    }
    return found.isEmpty ? null : found.single;
  }

  static RawChkDocument put(RawChkDocument doc, String name, List<int> bytes) {
    final i = index(doc, name, bytes.length);
    return i == null
        ? doc.appendSection(
            RawChkSection(
              nameBytes: name.codeUnits,
              declaredLength: bytes.length,
              payload: bytes,
              sourceOffset: doc.sourceLength,
              isDirty: true,
            ),
          )
        : doc.replaceSection(i, doc.sections[i].withPayload(bytes));
  }

  static (RawChkDocument, int) addText(RawChkDocument doc, String text) {
    if (text.contains('\u0000')) {
      throw const FormatException('Text cannot contain NUL.');
    }
    final views = const ChkStringViewDecoder().decode(doc);
    final tables = [...views.legacyTables, ...views.extendedTables];
    if (doc.sections
                .where((s) => s.name == 'STR ' || s.name == 'STRx')
                .length !=
            1 ||
        tables.length != 1 ||
        !tables.single.canAppendSafely) {
      throw const FormatException('One safe string table is required.');
    }
    final added = tables.single.withAddedRawString(rawBytes: utf8.encode(text));
    return (
      doc.replaceSection(tables.single.sectionIndex, added.section),
      added.stringId,
    );
  }

  static String stringLabel(RawChkDocument doc, int id) {
    final views = const ChkStringViewDecoder().decode(doc);
    final tables = doc.sections.any((s) => s.name == 'STRx')
        ? views.extendedTables
        : views.legacyTables;
    if (tables.length != 1) return 'String #$id';
    final bytes = tables.single.entryForId(id)?.rawBytes;
    return bytes == null
        ? 'String #$id'
        : utf8.decode(bytes, allowMalformed: true);
  }

  static String switchName(RawChkDocument doc, int id) {
    RangeError.checkValueInInterval(id, 0, 255);
    final i = index(doc, 'SWNM', 1024);
    if (i == null) return 'Switch ${id + 1}';
    final value = ByteData.sublistView(
      Uint8List.fromList(doc.sections[i].payload),
    ).getUint32(id * 4, Endian.little);
    return value == 0 ? 'Switch ${id + 1}' : stringLabel(doc, value);
  }

  static RawChkDocument renameSwitch(RawChkDocument doc, int id, String name) {
    RangeError.checkValueInInterval(id, 0, 255);
    final i = index(doc, 'SWNM', 1024);
    final bytes = i == null
        ? Uint8List(1024)
        : Uint8List.fromList(doc.sections[i].payload);
    var value = 0;
    if (name.isNotEmpty) {
      final added = addText(doc, name);
      doc = added.$1;
      value = added.$2;
    }
    ByteData.sublistView(bytes).setUint32(id * 4, value, Endian.little);
    return put(doc, 'SWNM', bytes);
  }

  static const propertyFields = [
    TriggerArgument('Hitpoints %', 5, 1, max: 100),
    TriggerArgument('Shields %', 6, 1, max: 100),
    TriggerArgument('Energy %', 7, 1, max: 100),
    TriggerArgument('Resource amount', 8, 4),
    TriggerArgument('Hangar count', 12, 2, max: 65535),
  ];
  static const specialNames = [
    'Cloaked',
    'Burrowed',
    'Lifted',
    'Hallucinated',
    'Invincible',
  ];
  static Map<String, int?> propertyValues(RawChkDocument doc, int id) {
    final bytes = property(doc, id),
        flags = ByteData.sublistView(
          Uint8List.fromList(property(doc, id)),
        ).getUint16(2, Endian.little);
    return {
      for (var i = 0; i < propertyFields.length; i++)
        propertyFields[i].name: flags & (1 << (i + 1)) == 0
            ? null
            : ChkTrigger.argument(bytes, propertyFields[i]),
    };
  }

  static List<bool?> specialValues(RawChkDocument doc, int id) {
    final data = ByteData.sublistView(Uint8List.fromList(property(doc, id)));
    return [
      for (var i = 0; i < 5; i++)
        data.getUint16(0, Endian.little) & (1 << i) == 0
            ? null
            : data.getUint16(14, Endian.little) & (1 << i) != 0,
    ];
  }

  static List<int> property(RawChkDocument doc, int id) {
    RangeError.checkValueInInterval(id, 1, 64);
    final i = index(doc, 'UPRP', 1280);
    return i == null
        ? List.filled(20, 0)
        : doc.sections[i].payload.sublist((id - 1) * 20, id * 20);
  }

  static int propertyUsers(RawChkDocument doc, int id) =>
      ChkTriggers.read(doc).records.fold(
        0,
        (sum, r) =>
            sum +
            [
              for (var a = 0; a < 64; a++)
                if (ChkTrigger.type(true, r.slot(true, a)) == 11 &&
                    ByteData.sublistView(
                          Uint8List.fromList(r.slot(true, a)),
                        ).getUint32(20, Endian.little) ==
                        id)
                  a,
            ].length,
      );
  static RawChkDocument editProperty(
    RawChkDocument doc,
    int id,
    Map<String, int?> values,
    List<bool?> special,
  ) {
    final before = property(doc, id);
    final bytes = Uint8List.fromList(before),
        data = ByteData.sublistView(Uint8List.fromList(before));
    var valid = data.getUint16(2, Endian.little);
    final output = ByteData.sublistView(bytes);
    for (var i = 0; i < propertyFields.length; i++) {
      final arg = propertyFields[i];
      if (!values.containsKey(arg.name)) continue;
      final value = values[arg.name];
      if (value == null) {
        valid &= ~(1 << (i + 1));
        continue;
      }
      if (value < 0 || value > arg.max) {
        throw FormatException('Invalid ${arg.name}');
      }
      valid |= 1 << (i + 1);
      switch (arg.width) {
        case 1:
          output.setUint8(arg.offset, value);
        case 2:
          output.setUint16(arg.offset, value, Endian.little);
        case 4:
          output.setUint32(arg.offset, value, Endian.little);
      }
    }
    if (special.length != 5) {
      throw const FormatException('Five special property states required.');
    }
    var flags = data.getUint16(14, Endian.little),
        mask = data.getUint16(0, Endian.little);
    for (var i = 0; i < 5; i++) {
      if (special[i] == null) {
        mask &= ~(1 << i);
      } else {
        mask |= 1 << i;
        flags = special[i]! ? flags | (1 << i) : flags & ~(1 << i);
      }
    }
    output.setUint16(0, mask, Endian.little);
    output.setUint16(2, valid, Endian.little);
    output.setUint16(14, flags, Endian.little);
    final p = index(doc, 'UPRP', 1280), u = index(doc, 'UPUS', 64);
    final props = p == null
        ? Uint8List(1280)
        : Uint8List.fromList(doc.sections[p].payload);
    final usage = u == null
        ? Uint8List(64)
        : Uint8List.fromList(doc.sections[u].payload);
    if (u == null) {
      for (var slot = 0; slot < 64; slot++) {
        if (props.sublist(slot * 20, (slot + 1) * 20).any((b) => b != 0) ||
            propertyUsers(doc, slot + 1) > 0) {
          usage[slot] = 1;
        }
      }
    }
    props.setRange((id - 1) * 20, id * 20, bytes);
    usage[id - 1] = 1;
    return put(put(doc, 'UPRP', props), 'UPUS', usage);
  }
}
