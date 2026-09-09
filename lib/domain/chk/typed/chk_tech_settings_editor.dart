import 'dart:typed_data';
import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_metadata_views.dart';

enum ChkTechField {
  useDefault('Use game defaults'),
  minerals('Mineral cost'),
  gas('Gas cost'),
  time('Research time (1/60 s)'),
  energy('Energy cost'),
  available('Available'),
  researched('Already researched'),
  inherit('Inherit map settings');

  const ChkTechField(this.label);
  final String label;
  bool get isCost => index <= energy.index;
  bool get isFlag => this == useDefault || !isCost;
  int get limit => isFlag ? 1 : 65535;
  int parse(String text) {
    if (!RegExp(r'^\d+$').hasMatch(text.trim())) {
      throw FormatException('$label requires a nonnegative integer.');
    }
    final result = int.parse(text.trim());
    RangeError.checkValueInInterval(result, 0, limit, label);
    return result;
  }
}

// Null player means map-wide costs or map-default states.
typedef TechSettingKey = (int, int?, ChkTechField);

final class ChkTechSettings {
  ChkTechSettings(
    this.count,
    this.costName,
    this.stateName,
    this.indices,
    this.data,
    this.issues,
    this.hasAlternate,
  );
  final int count;
  final String costName;
  final String stateName;
  final Map<String, int> indices;
  final Map<String, List<int>> data;
  final Map<String, String> issues;
  final bool hasAlternate;
  String section(ChkTechField field) => field.isCost ? costName : stateName;
  int offset(TechSettingKey key) {
    final (tech, player, field) = key;
    RangeError.checkValueInInterval(tech, 0, count - 1, 'tech');
    if (field.isCost) {
      if (player != null) throw ArgumentError('Costs have no player.');
      if (field == ChkTechField.useDefault) return tech;
      return count + (field.index - 1) * count * 2 + tech * 2;
    }
    if (player != null) {
      RangeError.checkValueInInterval(player, 0, 11, 'player');
    }
    if (field == ChkTechField.inherit) {
      if (player == null) throw ArgumentError('Inheritance requires a player.');
      return 26 * count + player * count + tech;
    }
    final start = field == ChkTechField.researched;
    return (player == null
            ? (start ? 25 : 24) * count
            : (start ? 12 : 0) * count + player * count) +
        tech;
  }

  int value(TechSettingKey key) {
    final offset = this.offset(key);
    final name = section(key.$3);
    final bytes = data[name];
    if (bytes == null) throw StateError(issues[name]!);
    return key.$3.isCost && !key.$3.isFlag
        ? bytes[offset] | bytes[offset + 1] << 8
        : bytes[offset];
  }
}

class ChkTechSettingsEditor {
  const ChkTechSettingsEditor();
  ChkTechSettings read(RawChkDocument document) {
    final versions = const ChkMetadataViewDecoder().decode(document).versions;
    if (versions.length != 1 ||
        versions.single.knownVersion == null ||
        document.sections.where((s) => s.name == 'VER ').length != 1) {
      throw StateError('Tech settings require one known VER section.');
    }
    final expanded = versions.single.knownVersion!.rawValue >= 205;
    final count = expanded ? 44 : 24;
    final cost = expanded ? 'TECx' : 'TECS';
    final states = expanded ? 'PTEx' : 'PTEC';
    final indices = <String, int>{};
    final data = <String, List<int>>{};
    final issues = <String, String>{};
    for (final name in [cost, states]) {
      final found = [
        for (var i = 0; i < document.sections.length; i++)
          if (document.sections[i].name == name) i,
      ];
      final size = name == cost ? count * 9 : count * 38;
      if (found.length != 1) {
        issues[name] = '$name: expected one section; found ${found.length}.';
      } else if (document.sections[found.single].payload.length != size) {
        issues[name] =
            '$name: expected $size bytes; found ${document.sections[found.single].payload.length}.';
      } else {
        indices[name] = found.single;
        data[name] = List.unmodifiable(document.sections[found.single].payload);
      }
    }
    return ChkTechSettings(
      count,
      cost,
      states,
      Map.unmodifiable(indices),
      Map.unmodifiable(data),
      Map.unmodifiable(issues),
      document.sections.any(
        (s) =>
            s.name == (expanded ? 'TECS' : 'TECx') ||
            s.name == (expanded ? 'PTEC' : 'PTEx'),
      ),
    );
  }

  Map<int, RawChkSection> edit(
    RawChkDocument document,
    Map<TechSettingKey, int> changes,
  ) {
    final original = read(document);
    final patches = <String, Uint8List>{};

    for (final entry in changes.entries) {
      final (_, player, field) = entry.key;
      final offset = original.offset(entry.key);
      if (player != null) {
        RangeError.checkValueInInterval(player, 0, 7, 'editable player');
      }
      if (original.value(entry.key) == entry.value) continue;
      RangeError.checkValueInInterval(entry.value, 0, field.limit, field.label);
      final name = original.section(field);
      final bytes = patches.putIfAbsent(
        name,
        () => Uint8List.fromList(original.data[name]!),
      );
      if (field.isCost && !field.isFlag) {
        ByteData.sublistView(
          bytes,
        ).setUint16(offset, entry.value, Endian.little);
      } else {
        bytes[offset] = entry.value;
      }
    }
    return {
      for (final e in patches.entries)
        original.indices[e.key]!: document.sections[original.indices[e.key]!]
            .withPayload(e.value),
    };
  }
}
