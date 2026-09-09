import 'dart:typed_data';
import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_metadata_views.dart';

enum ChkUpgradeField {
  useDefault('Use game defaults'),
  minerals('Base mineral cost'),
  mineralFactor('Mineral cost per level'),
  gas('Base gas cost'),
  gasFactor('Gas cost per level'),
  time('Base research time (1/60 s)'),
  timeFactor('Research time per level (1/60 s)'),
  maximum('Maximum level'),
  start('Starting level'),
  inherit('Inherit map levels');

  const ChkUpgradeField(this.label);
  final String label;
  bool get isCost => index <= timeFactor.index;
  bool get isFlag => this == useDefault || this == inherit;
  int get limit => isFlag
      ? 1
      : isCost
      ? 65535
      : 255;
  int parse(String text) {
    if (!RegExp(r'^\d+$').hasMatch(text.trim())) {
      throw FormatException('$label requires a nonnegative integer.');
    }
    final result = int.parse(text.trim());
    RangeError.checkValueInInterval(result, 0, limit, label);
    return result;
  }
}

// Null player means map-wide costs or map-default levels.
typedef UpgradeSettingKey = (int, int?, ChkUpgradeField);

final class ChkUpgradeSettings {
  ChkUpgradeSettings(
    this.count,
    this.costName,
    this.levelName,
    this.indices,
    this.data,
    this.issues,
    this.hasAlternate,
  );
  final int count;
  final String costName;
  final String levelName;
  final Map<String, int> indices;
  final Map<String, List<int>> data;
  final Map<String, String> issues;
  final bool hasAlternate;
  String section(ChkUpgradeField field) => field.isCost ? costName : levelName;
  int offset(UpgradeSettingKey key) {
    final (upgrade, player, field) = key;
    RangeError.checkValueInInterval(upgrade, 0, count - 1, 'upgrade');
    if (field.isCost) {
      if (player != null) throw ArgumentError('Costs have no player.');
      if (field == ChkUpgradeField.useDefault) return upgrade;
      return count +
          (count == 61 ? 1 : 0) +
          (field.index - 1) * count * 2 +
          upgrade * 2;
    }
    if (player != null) {
      RangeError.checkValueInInterval(player, 0, 11, 'player');
    }
    if (field == ChkUpgradeField.inherit) {
      if (player == null) throw ArgumentError('Inheritance requires a player.');
      return 26 * count + player * count + upgrade;
    }
    final start = field == ChkUpgradeField.start;
    return (player == null
            ? (start ? 25 : 24) * count
            : (start ? 12 : 0) * count + player * count) +
        upgrade;
  }

  int value(UpgradeSettingKey key) {
    final offset = this.offset(key);
    final name = section(key.$3);
    final bytes = data[name];
    if (bytes == null) throw StateError(issues[name]!);
    return key.$3.isCost && !key.$3.isFlag
        ? bytes[offset] | bytes[offset + 1] << 8
        : bytes[offset];
  }
}

class ChkUpgradeSettingsEditor {
  const ChkUpgradeSettingsEditor();
  ChkUpgradeSettings read(RawChkDocument document) {
    final versions = const ChkMetadataViewDecoder().decode(document).versions;
    if (versions.length != 1 ||
        versions.single.knownVersion == null ||
        document.sections.where((s) => s.name == 'VER ').length != 1) {
      throw StateError('Upgrade settings require one known VER section.');
    }
    final expanded = versions.single.knownVersion!.rawValue >= 205;
    final count = expanded ? 61 : 46;
    final cost = expanded ? 'UPGx' : 'UPGS';
    final levels = expanded ? 'PUPx' : 'UPGR';
    final indices = <String, int>{};
    final data = <String, List<int>>{};
    final issues = <String, String>{};
    for (final name in [cost, levels]) {
      final found = [
        for (var i = 0; i < document.sections.length; i++)
          if (document.sections[i].name == name) i,
      ];
      final size = name == cost ? count * 13 + (expanded ? 1 : 0) : count * 38;
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
    return ChkUpgradeSettings(
      count,
      cost,
      levels,
      Map.unmodifiable(indices),
      Map.unmodifiable(data),
      Map.unmodifiable(issues),
      document.sections.any(
        (s) =>
            s.name == (expanded ? 'UPGS' : 'UPGx') ||
            s.name == (expanded ? 'UPGR' : 'PUPx'),
      ),
    );
  }

  Map<int, RawChkSection> edit(
    RawChkDocument document,
    Map<UpgradeSettingKey, int> changes,
  ) {
    final original = read(document);
    final patches = <String, Uint8List>{};
    final pairs = <(int, int?)>{};
    final inheritances = <(int, int)>{};
    for (final entry in changes.entries) {
      final (upgrade, player, field) = entry.key;
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
      if (field == ChkUpgradeField.inherit) {
        inheritances.add((upgrade, player!));
      } else if (!field.isCost) {
        pairs.add((upgrade, player));
      }
    }
    int result(UpgradeSettingKey key) {
      final bytes = patches[original.section(key.$3)];
      return bytes == null ? original.value(key) : bytes[original.offset(key)];
    }

    for (final (upgrade, player) in inheritances) {
      pairs.add((
        upgrade,
        result((upgrade, player, ChkUpgradeField.inherit)) == 1 ? null : player,
      ));
    }
    for (final (upgrade, target) in pairs) {
      if (result((upgrade, target, ChkUpgradeField.start)) >
          result((upgrade, target, ChkUpgradeField.maximum))) {
        throw StateError(
          'Upgrade #$upgrade ${target == null ? "map defaults" : "Player ${target + 1}"}: starting level must not exceed maximum level.',
        );
      }
    }
    return {
      for (final e in patches.entries)
        original.indices[e.key]!: document.sections[original.indices[e.key]!]
            .withPayload(e.value),
    };
  }
}
