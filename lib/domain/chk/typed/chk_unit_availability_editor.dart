import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_metadata_views.dart';

enum ChkUnitAvailabilityField { global, player, inherit }

typedef UnitAvailabilityKey = (int?, int, ChkUnitAvailabilityField);

final class ChkUnitAvailability {
  ChkUnitAvailability(this.sectionIndex, List<int> bytes)
    : bytes = List.unmodifiable(bytes);
  final int sectionIndex;
  final List<int> bytes;
  static int offset(UnitAvailabilityKey key) {
    final (player, unit, field) = key;
    RangeError.checkValueInInterval(unit, 0, 227, 'unit');
    if (field == ChkUnitAvailabilityField.global) {
      if (player != null) {
        throw ArgumentError('Global availability has no player.');
      }
      return 2736 + unit;
    }
    if (player == null) throw ArgumentError('A player is required.');
    RangeError.checkValueInInterval(player, 0, 11, 'player');
    return (field == ChkUnitAvailabilityField.inherit ? 2964 : 0) +
        player * 228 +
        unit;
  }

  int value(UnitAvailabilityKey key) => bytes[offset(key)];
  bool? effective(int player, int unit) {
    final inherit = value((player, unit, ChkUnitAvailabilityField.inherit));
    if (inherit != 0 && inherit != 1) return null;
    final raw = value((
      inherit == 1 ? null : player,
      unit,
      inherit == 1
          ? ChkUnitAvailabilityField.global
          : ChkUnitAvailabilityField.player,
    ));
    return switch (raw) {
      0 => false,
      1 => true,
      _ => null,
    };
  }
}

class ChkUnitAvailabilityEditor {
  const ChkUnitAvailabilityEditor();
  ChkUnitAvailability read(RawChkDocument document) {
    final versions = const ChkMetadataViewDecoder().decode(document).versions;
    if (versions.length != 1 ||
        versions.single.knownVersion == null ||
        document.sections.where((s) => s.name == 'VER ').length != 1) {
      throw StateError('Unit availability requires one known VER section.');
    }
    final indices = [
      for (var i = 0; i < document.sections.length; i++)
        if (document.sections[i].name == 'PUNI') i,
    ];
    if (indices.length != 1) {
      throw StateError('PUNI: expected one section; found ${indices.length}.');
    }
    final payload = document.sections[indices.single].payload;
    if (payload.length != 5700) {
      throw StateError('PUNI: expected 5700 bytes; found ${payload.length}.');
    }
    return ChkUnitAvailability(indices.single, payload);
  }

  Map<int, RawChkSection> edit(
    RawChkDocument document,
    Map<UnitAvailabilityKey, int> changes,
  ) {
    final original = read(document);
    final bytes = original.bytes.toList();
    var changed = false;
    for (final e in changes.entries) {
      final offset = ChkUnitAvailability.offset(e.key);
      if (e.key.$1 != null) {
        RangeError.checkValueInInterval(e.key.$1!, 0, 7, 'editable player');
      }
      if (bytes[offset] == e.value) continue;
      RangeError.checkValueInInterval(e.value, 0, 1, 'availability flag');
      bytes[offset] = e.value;
      changed = true;
    }
    return changed
        ? {
            original.sectionIndex: document.sections[original.sectionIndex]
                .withPayload(bytes),
          }
        : {};
  }
}
