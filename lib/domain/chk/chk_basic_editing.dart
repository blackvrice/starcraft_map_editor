import 'dart:typed_data';
import 'raw_chk_document.dart';
import 'raw_chk_section.dart';
import '../placement/doodad_deletion_plan.dart';
import '../placement/doodad_placement_recipe.dart';

/// Supported CHK operations only. Unknown bits and unrelated bytes are retained.
/// Format facts: Chkdraft chk.h, revision 32d27861b16dda0b0f3d95e34bad894ea4efb2c3.
class ChkBasicEditing {
  const ChkBasicEditing();

  RawChkDocument patchSprites(
    RawChkDocument doc,
    Set<int> indices, {
    int? owner,
    bool? disabled,
  }) {
    dimensions(doc);
    final sprites = section(doc, 'THG2', stride: 10);
    if (sprites == null) throw StateError('THG2 section is missing.');
    if (owner != null) RangeError.checkValueInInterval(owner, 0, 11, 'owner');
    final bytes = sprites.payload, d = ByteData.sublistView(bytes);
    final dd = section(doc, 'DD2 ', stride: 8);
    final ddData = dd == null ? null : ByteData.sublistView(dd.payload);
    for (final i in indices) {
      RangeError.checkValueInInterval(i, 0, bytes.length ~/ 10 - 1, 'sprite');
      final at = i * 10, flags = d.getUint16(at + 8, Endian.little);
      if (ddData != null) {
        for (var k = 0; k < ddData.lengthInBytes; k += 8) {
          if (ddData.getUint16(k + 2, Endian.little) ==
                  d.getUint16(at + 2, Endian.little) &&
              ddData.getUint16(k + 4, Endian.little) ==
                  d.getUint16(at + 4, Endian.little)) {
            throw StateError(
              'Possible Doodad overlay: use the verified Doodad tool.',
            );
          }
        }
      }
      if (disabled != null && flags & 0x1000 != 0) {
        throw StateError(
          'Disabled applies only to sprite-units; pure sprites retain their flags.',
        );
      }
      if (owner != null) d.setUint8(at + 6, owner);
      if (disabled != null) {
        d.setUint16(
          at + 8,
          disabled ? flags | 0x8000 : flags & 0x7fff,
          Endian.little,
        );
      }
    }
    return _replace(doc, sprites, 'THG2', bytes);
  }

  RawChkDocument setDoodadEnabled(
    RawChkDocument doc, {
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    required bool enabled,
    int? overlayRecordIndex,
  }) {
    dimensions(doc);
    final dd = section(doc, 'DD2 ', stride: 8);
    if (dd == null) throw StateError('DD2 section is missing.');
    final bytes = dd.payload;
    RangeError.checkValueInInterval(
      recordIndex,
      0,
      bytes.length ~/ 8 - 1,
      'Doodad',
    );
    final at = recordIndex * 8;
    if (bytes[at + 7] > 1) throw StateError('Unknown Doodad enabled value.');
    final oldEnabled = bytes[at + 7];
    bytes[at + 7] = recipe.enabledValue;
    var normalized = _replace(doc, dd, 'DD2 ', bytes);
    final spr = section(doc, 'THG2', stride: 10);
    Uint8List? overlayBytes;
    if (recipe.overlay != null) {
      if (spr == null || overlayRecordIndex == null) {
        throw StateError('Select the matching overlay explicitly.');
      }
      overlayBytes = spr.payload;
      RangeError.checkValueInInterval(
        overlayRecordIndex,
        0,
        overlayBytes.length ~/ 10 - 1,
        'overlay',
      );
      final d = ByteData.sublistView(overlayBytes),
          offset = overlayRecordIndex * 10 + 8;
      final flags = d.getUint16(offset, Endian.little);
      final expected = recipe.overlay!.thg2Flags;
      if (flags != expected &&
          !(expected & 0x1000 == 0 &&
              oldEnabled == 1 &&
              flags == (expected | 0x8000))) {
        throw StateError(
          'Overlay flags do not match the verified Doodad state.',
        );
      }
      d.setUint16(offset, expected, Endian.little);
      normalized = _replace(
        normalized,
        section(normalized, 'THG2'),
        'THG2',
        overlayBytes,
      );
    }
    // Validation checks recipe, footprint, TILE and explicit overlay ownership.
    DoodadDeletionPlan.create(
      document: normalized,
      recipe: recipe,
      recordIndex: recordIndex,
      confirmedOverlayRecordIndex: overlayRecordIndex,
    );
    bytes[at + 7] = enabled ? 0 : 1;
    var result = _replace(doc, dd, 'DD2 ', bytes);
    if (overlayBytes != null && recipe.overlay!.thg2Flags & 0x1000 == 0) {
      final d = ByteData.sublistView(overlayBytes),
          offset = overlayRecordIndex! * 10 + 8;
      d.setUint16(
        offset,
        enabled
            ? recipe.overlay!.thg2Flags
            : recipe.overlay!.thg2Flags | 0x8000,
        Endian.little,
      );
      result = _replace(result, section(result, 'THG2'), 'THG2', overlayBytes);
    }
    return result;
  }

  RawChkSection? section(RawChkDocument doc, String name, {int? stride}) {
    final matches = doc.sections.where((s) => s.name == name).toList();
    if (matches.length > 1 ||
        (matches.isNotEmpty &&
            stride != null &&
            matches.single.payload.length % stride != 0)) {
      throw StateError('Ambiguous or damaged $name section.');
    }
    return matches.firstOrNull;
  }

  (int, int) dimensions(RawChkDocument doc) {
    if (doc.sections.any((s) => s.isEuddraftProtectionMarker)) {
      throw StateError('Protected maps cannot be edited.');
    }
    final dim = section(doc, 'DIM ');
    if (dim == null || dim.payload.length != 4) {
      throw StateError('A valid DIM section is required.');
    }
    final d = ByteData.sublistView(dim.payload);
    final w = d.getUint16(0, Endian.little), h = d.getUint16(2, Endian.little);
    if (w < 1 || h < 1 || w > 256 || h > 256) {
      throw StateError('Unsupported map dimensions.');
    }
    return (w, h);
  }

  RawChkDocument _replace(
    RawChkDocument doc,
    RawChkSection? old,
    String name,
    List<int> bytes,
  ) {
    if (old != null) {
      final prior = old.payload;
      if (prior.length == bytes.length &&
          Iterable.generate(bytes.length).every((i) => prior[i] == bytes[i])) {
        return doc;
      }
      return doc.replaceSection(
        doc.sections.indexOf(old),
        old.withPayload(bytes),
      );
    }
    return doc.appendSection(
      RawChkSection(
        nameBytes: name.codeUnits,
        declaredLength: bytes.length,
        payload: bytes,
        sourceOffset: doc.sourceLength,
        isDirty: true,
      ),
    );
  }

  List<int> fog(RawChkDocument doc) {
    final (w, h) = dimensions(doc);
    final mask = section(doc, 'MASK');
    if (mask == null) return List.unmodifiable(List.filled(w * h, 255));
    if (mask.payload.length != w * h) throw StateError('Damaged MASK grid.');
    return List.unmodifiable(mask.payload);
  }

  RawChkDocument paintFog(
    RawChkDocument doc,
    Iterable<(int, int)> cells, {
    required int player,
    required bool hidden,
  }) {
    RangeError.checkValueInInterval(player, 0, 7, 'player');
    final (w, h) = dimensions(doc);
    final bytes = fog(doc).toList(), bit = 1 << player;
    var changed = false;
    for (final (x, y) in cells) {
      RangeError.checkValueInInterval(x, 0, w - 1, 'x');
      RangeError.checkValueInInterval(y, 0, h - 1, 'y');
      final i = y * w + x,
          value = hidden
              ? bytes[y * w + x] | bit
              : bytes[y * w + x] & (255 ^ bit);
      changed |= bytes[i] != value;
      bytes[i] = value;
    }
    return changed ? _replace(doc, section(doc, 'MASK'), 'MASK', bytes) : doc;
  }

  /// Setting a state also enables its valid-state bit. Null restores inheritance
  /// without changing the stored state bit; unrelated and unknown bits survive.
  RawChkDocument patchUnits(
    RawChkDocument doc,
    Set<int> indices, {
    Map<int, bool?> states = const {},
    Map<int, bool> validFields = const {},
    int? owner,
    int? hitpoints,
    int? shields,
    int? energy,
    int? resources,
    int? hangar,
  }) {
    dimensions(doc);
    final units = section(doc, 'UNIT', stride: 36);
    if (units == null) throw StateError('UNIT section is missing.');
    final bytes = units.payload, d = ByteData.sublistView(bytes);
    for (final bit in states.keys) {
      if (![1, 2, 4, 8, 16].contains(bit)) {
        throw ArgumentError('Unsupported unit state.');
      }
    }
    for (final bit in validFields.keys) {
      if (![1, 2, 4, 8, 16, 32].contains(bit)) {
        throw ArgumentError('Unsupported valid field.');
      }
    }
    if (owner != null) RangeError.checkValueInInterval(owner, 0, 11, 'owner');
    for (final p in [hitpoints, shields, energy]) {
      if (p != null) RangeError.checkValueInInterval(p, 0, 100, 'percent');
    }
    if (resources != null) {
      RangeError.checkValueInInterval(resources, 0, 0xffffffff, 'resources');
    }
    if (hangar != null) {
      RangeError.checkValueInInterval(hangar, 0, 65535, 'hangar');
    }
    for (final i in indices) {
      RangeError.checkValueInInterval(i, 0, bytes.length ~/ 36 - 1, 'unit');
      final at = i * 36;
      if (owner != null &&
          d.getUint16(at + 8, Endian.little) == 214 &&
          owner != d.getUint8(at + 16)) {
        throw StateError('Use the owner-specific start-location tool.');
      }
      if (owner != null && d.getUint16(at + 10, Endian.little) != 0) {
        throw StateError(
          'Change owners of linked units only after unlinking them.',
        );
      }
      var state = d.getUint16(at + 26, Endian.little),
          valid = d.getUint16(at + 12, Endian.little);
      for (final e in states.entries) {
        if (e.value == null) {
          valid &= 65535 ^ e.key;
        } else {
          valid |= e.key;
          state = e.value! ? state | e.key : state & (65535 ^ e.key);
        }
      }
      d.setUint16(at + 12, valid, Endian.little);
      d.setUint16(at + 26, state, Endian.little);
      var fields = d.getUint16(at + 14, Endian.little);
      for (final e in validFields.entries) {
        fields = e.value ? fields | e.key : fields & (65535 ^ e.key);
      }
      final values = [owner, hitpoints, shields, energy, resources, hangar];
      for (var f = 0; f < values.length; f++) {
        final v = values[f];
        if (v == null) continue;
        fields |= 1 << f;
        if (f < 4) {
          d.setUint8(at + 16 + f, v);
        } else if (f == 4) {
          d.setUint32(at + 20, v, Endian.little);
        } else {
          d.setUint16(at + 24, v, Endian.little);
        }
      }
      d.setUint16(at + 14, fields, Endian.little);
    }
    return _replace(doc, units, 'UNIT', bytes);
  }

  RawChkDocument setLocationElevation(RawChkDocument doc, int index, int mask) {
    dimensions(doc);
    RangeError.checkValueInInterval(mask, 0, 63, 'elevations');
    final s = section(doc, 'MRGN', stride: 20);
    if (s == null || ![1280, 5100].contains(s.payload.length)) {
      throw StateError('A valid location table is required.');
    }
    RangeError.checkValueInInterval(
      index,
      0,
      s.payload.length ~/ 20 - 1,
      'location',
    );
    final bytes = s.payload,
        d = ByteData.sublistView(bytes),
        at = index * 20 + 18;
    d.setUint16(
      at,
      (d.getUint16(at, Endian.little) & 0xffc0) | mask,
      Endian.little,
    );
    return _replace(doc, s, 'MRGN', bytes);
  }

  RawChkDocument setStartLocation(
    RawChkDocument doc, {
    required int player,
    required int x,
    required int y,
  }) {
    final (w, h) = dimensions(doc);
    RangeError.checkValueInInterval(player, 0, 7, 'player');
    RangeError.checkValueInInterval(x, 0, w * 32 - 1, 'x');
    RangeError.checkValueInInterval(y, 0, h * 32 - 1, 'y');
    final s = section(doc, 'UNIT', stride: 36),
        bytes = s?.payload ?? Uint8List(0);
    final d = ByteData.sublistView(bytes), matches = <int>[], classes = <int>{};
    for (var at = 0; at < bytes.length; at += 36) {
      classes.add(d.getUint32(at, Endian.little));
      if (d.getUint16(at + 8, Endian.little) == 214 &&
          d.getUint8(at + 16) == player) {
        matches.add(at);
      }
    }
    if (matches.length > 1) {
      throw StateError('Duplicate start locations must be reviewed manually.');
    }
    if (matches.isNotEmpty) {
      final at = matches.single;
      d.setUint16(at + 4, x, Endian.little);
      d.setUint16(at + 6, y, Endian.little);
      return _replace(doc, s, 'UNIT', bytes);
    }
    var id = 1;
    while (classes.contains(id)) {
      id++;
    }
    final fresh = ByteData(36)
      ..setUint32(0, id, Endian.little)
      ..setUint16(4, x, Endian.little)
      ..setUint16(6, y, Endian.little)
      ..setUint16(8, 214, Endian.little)
      ..setUint16(14, 1, Endian.little)
      ..setUint8(16, player);
    return _replace(doc, s, 'UNIT', [...bytes, ...fresh.buffer.asUint8List()]);
  }

  /// Mutual references with unique nonzero class IDs. No geometry is inferred.
  RawChkDocument linkUnits(
    RawChkDocument doc,
    int first,
    int second, {
    required bool addon,
  }) {
    dimensions(doc);
    final s = section(doc, 'UNIT', stride: 36);
    if (s == null || first == second) {
      throw StateError('Select two different units.');
    }
    final bytes = s.payload,
        d = ByteData.sublistView(bytes),
        count = bytes.length ~/ 36;
    for (final i in [first, second]) {
      RangeError.checkValueInInterval(i, 0, count - 1, 'unit');
    }
    final a = first * 36, b = second * 36;
    if (d.getUint8(a + 16) != d.getUint8(b + 16)) {
      throw StateError('Linked units must have the same owner.');
    }
    for (final at in [a, b]) {
      if (d.getUint16(at + 10, Endian.little) != 0 ||
          d.getUint32(at + 32, Endian.little) != 0) {
        throw StateError('Unlink existing relations first.');
      }
    }
    final ta = d.getUint16(a + 8, Endian.little),
        tb = d.getUint16(b + 8, Endian.little);
    const addons = {
      106: [107, 108],
      113: [120],
      114: [115],
      116: [117, 118],
    };
    if (addon
        ? !(addons[ta]?.contains(tb) ?? false) &&
              !(addons[tb]?.contains(ta) ?? false)
        : ta != 134 || tb != 134) {
      throw StateError('Incompatible unit relationship.');
    }
    final ids = <int, int>{};
    for (var at = 0; at < bytes.length; at += 36) {
      final id = d.getUint32(at, Endian.little);
      if (id == 0) continue;
      if (ids.containsKey(id)) throw StateError('Ambiguous unit class IDs.');
      ids[id] = at;
    }
    for (final at in [a, b]) {
      if (d.getUint32(at, Endian.little) == 0) {
        var id = 1;
        while (ids.containsKey(id)) {
          id++;
        }
        d.setUint32(at, id, Endian.little);
        ids[id] = at;
      }
    }
    d.setUint16(a + 10, addon ? 0x400 : 0x200, Endian.little);
    d.setUint16(b + 10, addon ? 0x400 : 0x200, Endian.little);
    d.setUint32(a + 32, d.getUint32(b, Endian.little), Endian.little);
    d.setUint32(b + 32, d.getUint32(a, Endian.little), Endian.little);
    return _replace(doc, s, 'UNIT', bytes);
  }

  RawChkDocument unlinkUnits(RawChkDocument doc, Set<int> indices) {
    dimensions(doc);
    final s = section(doc, 'UNIT', stride: 36);
    if (s == null) throw StateError('UNIT section is missing.');
    final bytes = s.payload,
        d = ByteData.sublistView(bytes),
        expanded = {...indices};
    for (final i in indices) {
      RangeError.checkValueInInterval(i, 0, bytes.length ~/ 36 - 1, 'unit');
      final at = i * 36, flags = d.getUint16(at + 10, Endian.little);
      if (flags == 0 && d.getUint32(at + 32, Endian.little) == 0) continue;
      if (![0x200, 0x400].contains(flags)) {
        throw StateError('Unknown relation flags are preserved.');
      }
      final id = d.getUint32(at, Endian.little),
          peer = d.getUint32(at + 32, Endian.little);
      final hits = [
        for (var k = 0; k < bytes.length ~/ 36; k++)
          if (d.getUint32(k * 36, Endian.little) == peer) k,
      ];
      if (id == 0 ||
          peer == 0 ||
          Iterable.generate(
                bytes.length ~/ 36,
              ).where((k) => d.getUint32(k * 36, Endian.little) == id).length !=
              1 ||
          hits.length != 1 ||
          hits.single == i ||
          d.getUint32(hits.single * 36 + 32, Endian.little) != id ||
          d.getUint16(hits.single * 36 + 10, Endian.little) != flags) {
        throw StateError('Ambiguous relation is preserved.');
      }
      expanded.add(hits.single);
    }
    for (final i in expanded) {
      d.setUint16(i * 36 + 10, 0, Endian.little);
      d.setUint32(i * 36 + 32, 0, Endian.little);
    }
    return _replace(doc, s, 'UNIT', bytes);
  }
}
