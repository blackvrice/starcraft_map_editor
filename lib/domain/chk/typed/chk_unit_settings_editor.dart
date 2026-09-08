import 'dart:convert';
import 'dart:typed_data';
import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_metadata_views.dart';
import 'chk_string_views.dart';

enum ChkUnitSettingField {
  useDefault(0, 1, 1, 'Use defaults'),
  hitpoints(228, 4, 0xffffffff, 'Hit points'),
  shields(1140, 2, 65535, 'Shields'),
  armor(1596, 1, 255, 'Armor'),
  buildTime(1824, 2, 65535, 'Build time (1/60 s)'),
  minerals(2280, 2, 65535, 'Mineral cost'),
  gas(2736, 2, 65535, 'Gas cost');

  const ChkUnitSettingField(this.offset, this.width, this.maximum, this.label);
  final int offset;
  final int width;
  final int maximum;
  final String label;

  String display(int value) {
    if (this != hitpoints) return '$value';
    final fraction = ((value % 256) * 390625)
        .toString()
        .padLeft(8, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${value ~/ 256}${fraction.isEmpty ? '' : '.$fraction'}';
  }

  int parse(String text) {
    final input = text.trim();
    if (this == hitpoints) {
      if (!RegExp(r'^\d{1,8}(\.\d{1,8})?$').hasMatch(input)) {
        throw FormatException(
          'Hit points require a nonnegative decimal in steps of 1/256.',
        );
      }
      final parts = input.split('.');
      final scale = parts.length == 1
          ? 1
          : int.parse('1${'0' * parts[1].length}');
      final numerator = int.parse(parts.join()) * 256;
      if (numerator % scale != 0) {
        throw FormatException('Hit points must be a multiple of 1/256.');
      }
      final value = numerator ~/ scale;
      RangeError.checkValueInInterval(value, 0, maximum, label);
      return value;
    }
    if (!RegExp(r'^\d+$').hasMatch(input)) {
      throw FormatException('$label requires a nonnegative integer.');
    }
    final value = int.parse(input);
    RangeError.checkValueInInterval(value, 0, maximum, label);
    return value;
  }
}

final class ChkUnitSettings {
  ChkUnitSettings(
    this.sectionIndex,
    this.sectionName,
    this.weaponCount,
    this.hasAlternate,
    ByteData data,
    this.table,
    this.tableIssue,
  ) : _data = data;
  final int sectionIndex;
  final String sectionName;
  final int weaponCount;
  final bool hasAlternate;
  final ByteData _data;
  final ChkStringTableView? table;
  final String? tableIssue;
  int value(int unit, ChkUnitSettingField field) {
    RangeError.checkValueInInterval(unit, 0, 227, 'unit');
    final offset = field.offset + unit * field.width;
    return switch (field.width) {
      1 => _data.getUint8(offset),
      2 => _data.getUint16(offset, Endian.little),
      _ => _data.getUint32(offset, Endian.little),
    };
  }

  int damage(int weapon, {bool bonus = false}) {
    RangeError.checkValueInInterval(weapon, 0, weaponCount - 1, 'weapon');
    return _data.getUint16(
      3648 + (bonus ? weaponCount * 2 : 0) + weapon * 2,
      Endian.little,
    );
  }

  String name(int unit) {
    RangeError.checkValueInInterval(unit, 0, 227, 'unit');
    if (table == null) throw StateError(tableIssue!);
    final id = _data.getUint16(3192 + unit * 2, Endian.little);
    if (id == 0) return '';
    final entry = table!.entryForId(id);
    if (entry == null || !entry.isStructurallyValid) {
      throw StateError('Invalid unit name string ID $id.');
    }
    return utf8.decode(entry.rawBytes!, allowMalformed: false);
  }
}

class ChkUnitSettingsEditor {
  const ChkUnitSettingsEditor();
  ChkUnitSettings read(RawChkDocument document) {
    final versions = const ChkMetadataViewDecoder().decode(document).versions;
    if (versions.length != 1 ||
        versions.single.knownVersion == null ||
        document.sections.where((s) => s.name == 'VER ').length != 1) {
      throw StateError('Unit settings require one known VER section.');
    }
    final expanded = versions.single.knownVersion!.rawValue >= 205;
    final name = expanded ? 'UNIx' : 'UNIS';
    final count = expanded ? 130 : 100;
    final indices = [
      for (var i = 0; i < document.sections.length; i++)
        if (document.sections[i].name == name) i,
    ];
    if (indices.length != 1) {
      throw StateError('$name: expected one section; found ${indices.length}.');
    }
    final payload = document.sections[indices.single].payload;
    final size = 3648 + count * 4;
    if (payload.length != size) {
      throw StateError('$name: expected $size bytes; found ${payload.length}.');
    }
    final views = const ChkStringViewDecoder().decode(document);
    final tables = [...views.legacyTables, ...views.extendedTables];
    final safe =
        document.sections
                .where((s) => s.name == 'STR ' || s.name == 'STRx')
                .length ==
            1 &&
        tables.length == 1 &&
        tables.single.canAppendSafely;
    return ChkUnitSettings(
      indices.single,
      name,
      count,
      document.sections.any((s) => s.name == (expanded ? 'UNIS' : 'UNIx')),
      ByteData.sublistView(Uint8List.fromList(payload)),
      safe ? tables.single : null,
      safe ? null : 'Unit names require one safe STR or STRx table.',
    );
  }

  Map<int, RawChkSection> edit(
    RawChkDocument document, {
    Map<(int, ChkUnitSettingField), int> values = const {},
    Map<(int, bool), int> damage = const {},
    Map<int, String> names = const {},
  }) {
    final original = read(document);
    final section = document.sections[original.sectionIndex];
    final source = section.payload;
    final bytes = Uint8List.fromList(source);
    final data = ByteData.sublistView(bytes);
    for (final e in values.entries) {
      final (unit, field) = e.key;
      if (original.value(unit, field) == e.value) continue;
      RangeError.checkValueInInterval(e.value, 0, field.maximum, field.label);
      final offset = field.offset + unit * field.width;
      switch (field.width) {
        case 1:
          data.setUint8(offset, e.value);
        case 2:
          data.setUint16(offset, e.value, Endian.little);
        case 4:
          data.setUint32(offset, e.value, Endian.little);
      }
    }
    for (final e in damage.entries) {
      final (weapon, bonus) = e.key;
      original.damage(weapon, bonus: bonus);
      RangeError.checkValueInInterval(e.value, 0, 65535, 'damage');
      data.setUint16(
        3648 + (bonus ? original.weaponCount * 2 : 0) + weapon * 2,
        e.value,
        Endian.little,
      );
    }
    var table = original.table;
    final replacements = <int, RawChkSection>{};
    for (final e in names.entries) {
      if (original.name(e.key) == e.value) continue;
      var id = 0;
      if (e.value.isNotEmpty) {
        if (e.value.contains('\u0000')) {
          throw ArgumentError('Unit names cannot contain NUL.');
        }
        if (table!.declaredStringCount >= 65535) {
          throw StateError('Unit name IDs cannot exceed 65535.');
        }
        final added = table.withAddedRawString(rawBytes: utf8.encode(e.value));
        replacements[table.sectionIndex] = added.section;
        id = added.stringId;
        final updated = document.replaceSection(
          table.sectionIndex,
          added.section,
        );
        table = read(updated).table;
      }
      data.setUint16(3192 + e.key * 2, id, Endian.little);
    }
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != source[i]) {
        replacements[original.sectionIndex] = section.withPayload(bytes);
        break;
      }
    }
    return replacements;
  }
}
