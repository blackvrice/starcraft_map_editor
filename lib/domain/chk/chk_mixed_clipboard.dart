import 'dart:math' as math;
import 'dart:typed_data';
import 'chk.dart';
import 'chk_basic_editing.dart';
import 'chk_editing_clipboard.dart';
import '../placement/doodad_placement_recipe.dart';
import '../terrain/isom_doodad_overlay.dart';
import '../terrain/isom_terrain_conversion.dart';
import '../terrain/isom_terrain_paint.dart';

enum MixedClipboardProfile { raw, isom }

final class ClipboardRegion {
  ClipboardRegion(this.left, this.top, this.right, this.bottom) {
    RangeError.checkValueInInterval(left, 0, 255, 'left');
    RangeError.checkValueInInterval(top, 0, 255, 'top');
    RangeError.checkValueInInterval(right, left, 255, 'right');
    RangeError.checkValueInInterval(bottom, top, 255, 'bottom');
  }
  final int left, top, right, bottom;
  int get width => right - left + 1;
  int get height => bottom - top + 1;
  bool contains(int x, int y, int w, int h) =>
      x >= left && y >= top && x + w <= right + 1 && y + h <= bottom + 1;
  bool intersects(int x, int y, int w, int h) =>
      x < right + 1 && y < bottom + 1 && x + w > left && y + h > top;
}

final class MixedClipboardData {
  MixedClipboardData({
    required List<DoodadPlacementRecipe> recipes,
    this.catalog,
    this.brush,
  }) : recipes = List.unmodifiable(recipes);
  final List<DoodadPlacementRecipe> recipes;
  final IsomTerrainCatalog? catalog;
  final IsomBrushCatalog? brush;
}

/// An immutable verified region. Cross-document callers must remap references.
final class ChkMixedClipboard {
  ChkMixedClipboard._(
    this.source,
    this.region,
    this.profile,
    this.data,
    this.objects,
    this.selected,
    this.doodads,
    this.shapes,
    this.raw,
    this.tile,
    this.skippedReserved,
  );
  final RawChkDocument source;
  final ClipboardRegion region;
  final MixedClipboardProfile profile;
  final MixedClipboardData data;
  final ChkEditingClipboard? objects;
  final Map<String, Set<int>> selected;
  final List<IsomDoodadInstance> doodads;
  final Map<IsomDiamond, int> shapes;
  final List<int> raw;
  final List<int>? tile;
  final int skippedReserved;
  static const editor = ChkBasicEditing();
  int get objectCount =>
      selected.values.fold(0, (n, v) => n + v.length) + doodads.length;
  Set<String> get sections => {
    'MTXM',
    if (tile != null || profile == MixedClipboardProfile.isom) 'TILE',
    if (profile == MixedClipboardProfile.isom) 'ISOM',
    if (doodads.isNotEmpty) 'DD2 ',
    ...selected.keys,
  };

  static int _tileset(RawChkDocument doc) {
    editor.dimensions(doc);
    final era = editor.section(doc, 'ERA ');
    if (era == null ||
        era.payload.length != 2 ||
        era.payload[1] != 0 ||
        era.payload[0] > 7) {
      throw StateError('MIXED_CLIPBOARD_TILESET');
    }
    return era.payload[0];
  }

  static List<IsomDoodadInstance> layout(
    RawChkDocument doc,
    MixedClipboardData data, {
    required bool isom,
  }) {
    final dd = editor.section(doc, 'DD2 ', stride: 8);
    if (!isom && (dd == null || dd.payload.isEmpty)) return const [];
    final instances = IsomDoodadOverlay.read(
      doc,
      data.recipes,
      allowDisabled: true,
      allowRawOverrides: !isom,
    ).instances;
    final (w, _) = editor.dimensions(doc);
    final underlying = _grid(doc, 'TILE');
    for (final d in instances) {
      for (final c in d.recipe.footprint) {
        if (c.writesTerrain &&
            underlying.getUint16(
                  ((d.bounds.y + c.y) * w + d.bounds.x + c.x) * 2,
                  Endian.little,
                ) ==
                c.rawTileValue) {
          throw StateError('MIXED_CLIPBOARD_UNDERLYING');
        }
      }
    }
    return instances;
  }

  static RawChkDocument _withoutDoodads(RawChkDocument doc) {
    final dd = editor.section(doc, 'DD2 ', stride: 8);
    return dd == null
        ? doc
        : doc.replaceSection(doc.sections.indexOf(dd), dd.withPayload([]));
  }

  static ByteData _grid(RawChkDocument doc, String name) {
    final (w, h) = editor.dimensions(doc);
    final section = editor.section(doc, name);
    if (section == null || section.payload.length != w * h * 2) {
      throw StateError('MIXED_CLIPBOARD_GRID: $name');
    }
    return ByteData.sublistView(section.payload);
  }

  static RawChkDocument _put(RawChkDocument doc, String name, List<int> bytes) {
    final old = editor.section(doc, name);
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

  static ChkMixedClipboard capture(
    RawChkDocument doc, {
    required ClipboardRegion region,
    required MixedClipboardProfile profile,
    required Set<String> kinds,
    required Map<int, int> overlays,
    required MixedClipboardData data,
  }) {
    final (w, h) = editor.dimensions(doc);
    final era = _tileset(doc);
    if (region.right >= w ||
        region.bottom >= h ||
        kinds.any((k) => !{'UNIT', 'THG2', 'MRGN', 'DD2 '}.contains(k))) {
      throw StateError('MIXED_CLIPBOARD_REGION');
    }
    final isom = profile == MixedClipboardProfile.isom;
    if (isom != doc.sections.any((s) => s.name == 'ISOM')) {
      throw StateError('MIXED_CLIPBOARD_PROFILE');
    }
    if (isom &&
        (data.catalog?.tileset != era ||
            data.brush == null ||
            region.left % 4 != 0 ||
            region.top.isOdd ||
            region.width % 4 != 0 ||
            region.height.isOdd)) {
      throw StateError('MIXED_CLIPBOARD_ISOM_ALIGNMENT');
    }
    final all = layout(doc, data, isom: isom);
    final picked = <IsomDoodadInstance>[];
    for (final d in all) {
      final b = d.bounds;
      if (!region.intersects(b.x, b.y, b.width, b.height)) continue;
      if (!kinds.contains('DD2 ') ||
          !region.contains(b.x, b.y, b.width, b.height)) {
        throw StateError('MIXED_CLIPBOARD_PARTIAL_DOODAD');
      }
      picked.add(d);
    }
    final selected = <String, Set<int>>{};
    final ownedSprites = <int>{};
    final ddBytes = editor.section(doc, 'DD2 ', stride: 8)?.payload;
    final spriteBytes = editor.section(doc, 'THG2', stride: 10)?.payload;
    final spriteCenters = <(int, int), int>{};
    if (spriteBytes != null) {
      final sp = ByteData.sublistView(spriteBytes);
      for (var i = 0; i < spriteBytes.length; i += 10) {
        final center = (
          sp.getUint16(i + 2, Endian.little),
          sp.getUint16(i + 4, Endian.little),
        );
        spriteCenters.update(center, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    for (final d in picked) {
      final r = d.recipe, index = overlays[d.recordIndex];
      if (r.overlay == null) {
        if (index != null) throw StateError('MIXED_CLIPBOARD_OVERLAY');
        continue;
      }
      if (index == null ||
          spriteBytes == null ||
          index < 0 ||
          index >= spriteBytes.length ~/ 10 ||
          !ownedSprites.add(index)) {
        throw StateError('MIXED_CLIPBOARD_OVERLAY');
      }
      final dd = ByteData.sublistView(ddBytes!),
          sp = ByteData.sublistView(spriteBytes);
      final at = d.recordIndex * 8, st = index * 10;
      final flags =
          r.overlay!.thg2Flags |
          (r.overlay!.thg2Flags & 0x1000 == 0 && dd.getUint8(at + 7) == 1
              ? 0x8000
              : 0);
      if (sp.getUint16(st, Endian.little) != r.overlay!.id ||
          sp.getUint16(st + 2, Endian.little) !=
              dd.getUint16(at + 2, Endian.little) ||
          sp.getUint16(st + 4, Endian.little) !=
              dd.getUint16(at + 4, Endian.little) ||
          sp.getUint8(st + 6) != dd.getUint8(at + 6) ||
          sp.getUint8(st + 7) != 0 ||
          sp.getUint16(st + 8, Endian.little) != flags) {
        throw StateError('MIXED_CLIPBOARD_OVERLAY');
      }
      // Confirmation cannot disambiguate multiple records at the same center.
      if (spriteCenters[(
            sp.getUint16(st + 2, Endian.little),
            sp.getUint16(st + 4, Endian.little),
          )] !=
          1) {
        throw StateError('MIXED_CLIPBOARD_OVERLAY');
      }
    }
    if (overlays.keys.any(
      (i) => !picked.any((d) => d.recordIndex == i && d.recipe.overlay != null),
    )) {
      throw StateError('MIXED_CLIPBOARD_OVERLAY');
    }
    var skipped = 0;
    for (final (name, stride) in [('UNIT', 36), ('THG2', 10), ('MRGN', 20)]) {
      final bytes = editor.section(doc, name, stride: stride)?.payload;
      if (bytes == null) continue;
      final b = ByteData.sublistView(bytes);
      for (var i = 0; i < bytes.length ~/ stride; i++) {
        var include = false;
        if (name == 'MRGN') {
          if (!kinds.contains(name) ||
              bytes
                  .sublist(i * stride, (i + 1) * stride)
                  .every((v) => v == 0)) {
            continue;
          }
          final a = b.getUint32(i * 20, Endian.little),
              c = b.getUint32(i * 20 + 8, Endian.little),
              t = b.getUint32(i * 20 + 4, Endian.little),
              z = b.getUint32(i * 20 + 12, Endian.little);
          final l = math.min(a, c),
              right = math.max(a, c),
              top = math.min(t, z),
              bottom = math.max(t, z);
          include =
              l >= region.left * 32 &&
              top >= region.top * 32 &&
              right <= (region.right + 1) * 32 &&
              bottom <= (region.bottom + 1) * 32;
          if (i == 63) {
            if (include) skipped++;
            continue;
          }
          if (!include &&
              l < (region.right + 1) * 32 &&
              right > region.left * 32 &&
              top < (region.bottom + 1) * 32 &&
              bottom > region.top * 32) {
            throw StateError('MIXED_CLIPBOARD_PARTIAL_LOCATION');
          }
        } else {
          final at = i * stride + (name == 'UNIT' ? 4 : 2),
              x = b.getUint16(at, Endian.little),
              y = b.getUint16(at + 2, Endian.little);
          include =
              kinds.contains(name) &&
              x >= region.left * 32 &&
              x < (region.right + 1) * 32 &&
              y >= region.top * 32 &&
              y < (region.bottom + 1) * 32;
          if (name == 'UNIT' &&
              include &&
              b.getUint16(i * 36 + 8, Endian.little) == 214) {
            skipped++;
            continue;
          }
          if (name == 'THG2' && ownedSprites.contains(i)) include = true;
        }
        if (include) selected.putIfAbsent(name, () => {}).add(i);
      }
    }
    final sanitized = _withoutDoodads(doc);
    final objects = selected.isEmpty
        ? null
        : ChkEditingClipboard.capture(sanitized, selected);
    // Reject incoming links as well as missing outgoing peers before a cut.
    if (selected['UNIT'] case final units?) {
      final b = ByteData.sublistView(
        editor.section(doc, 'UNIT', stride: 36)!.payload,
      );
      final ids = {for (final i in units) b.getUint32(i * 36, Endian.little)}
        ..remove(0);
      for (var i = 0; i < b.lengthInBytes ~/ 36; i++) {
        if (!units.contains(i) &&
            ids.contains(b.getUint32(i * 36 + 32, Endian.little))) {
          throw StateError('MIXED_CLIPBOARD_UNIT_LINK');
        }
      }
    }
    final shapes = <IsomDiamond, int>{};
    if (isom) {
      final base = IsomDoodadOverlay.read(
        doc,
        data.recipes,
        allowDisabled: true,
      ).base;
      const IsomTerrainPaint().previewShapes(
        base,
        data.catalog!,
        data.brush!,
        assignments: {},
      );
      for (final e in IsomTerrainPaint.readDiamonds(
        base,
        data.brush!,
      ).entries) {
        if (region.contains(e.key.$1 * 2 - 2, e.key.$2 - 1, 4, 2)) {
          shapes[e.key] = e.value;
        }
      }
      if (shapes.isEmpty) throw StateError('MIXED_CLIPBOARD_ISOM_ALIGNMENT');
    }
    final m = _grid(doc, 'MTXM');
    final t = editor.section(doc, 'TILE') == null ? null : _grid(doc, 'TILE');
    List<int> collect(ByteData b) => [
      for (var y = region.top; y <= region.bottom; y++)
        for (var x = region.left; x <= region.right; x++)
          b.getUint16((y * w + x) * 2, Endian.little),
    ];
    return ChkMixedClipboard._(
      doc,
      region,
      profile,
      data,
      objects,
      Map.unmodifiable({
        for (final e in selected.entries) e.key: Set<int>.unmodifiable(e.value),
      }),
      List.unmodifiable(picked),
      Map.unmodifiable(shapes),
      List.unmodifiable(collect(m)),
      t == null ? null : List.unmodifiable(collect(t)),
      skipped,
    );
  }

  RawChkDocument paste(
    RawChkDocument target, {
    required int x,
    required int y,
    Map<int, int> locationStrings = const {},
    bool includeLocations = true,
  }) {
    _checkLocationReferences(target, locationStrings);
    final (w, h) = editor.dimensions(target);
    if (_tileset(target) != _tileset(source) ||
        x < 0 ||
        y < 0 ||
        x + region.width > w ||
        y + region.height > h) {
      throw StateError('MIXED_CLIPBOARD_DESTINATION');
    }
    final isom = profile == MixedClipboardProfile.isom,
        dx = x - region.left,
        dy = y - region.top;
    if (isom != target.sections.any((s) => s.name == 'ISOM') ||
        (isom && (dx % 4 != 0 || dy % 2 != 0))) {
      throw StateError('MIXED_CLIPBOARD_ISOM_ALIGNMENT');
    }
    final destination = ClipboardRegion(
      x,
      y,
      x + region.width - 1,
      y + region.height - 1,
    );
    for (final d in layout(target, data, isom: isom)) {
      final b = d.bounds;
      if (destination.intersects(b.x, b.y, b.width, b.height)) {
        throw StateError('MIXED_CLIPBOARD_TARGET_DOODAD');
      }
    }
    var result = target;
    if (isom) {
      final overlay = IsomDoodadOverlay.read(
        target,
        data.recipes,
        allowDisabled: true,
      );
      result = overlay.restore(
        const IsomTerrainPaint()
            .previewShapes(
              overlay.base,
              data.catalog!,
              data.brush!,
              assignments: {
                for (final e in shapes.entries)
                  (e.key.$1 + dx ~/ 2, e.key.$2 + dy): e.value,
              },
              solveRegion: true,
            )
            .result,
      );
    } else {
      for (final (name, values) in [
        ('MTXM', raw),
        if (tile != null) ('TILE', tile!),
      ]) {
        final grid = _grid(result, name);
        for (var cy = 0; cy < region.height; cy++) {
          for (var cx = 0; cx < region.width; cx++) {
            grid.setUint16(
              ((y + cy) * w + x + cx) * 2,
              values[cy * region.width + cx],
              Endian.little,
            );
          }
        }
        result = _put(result, name, grid.buffer.asUint8List());
      }
    }
    final existingSprites = editor.section(target, 'THG2', stride: 10)?.payload;
    final occupiedCenters = <(int, int)>{};
    if (existingSprites != null) {
      final sp = ByteData.sublistView(existingSprites);
      for (var i = 0; i < sp.lengthInBytes; i += 10) {
        occupiedCenters.add((
          sp.getUint16(i + 2, Endian.little),
          sp.getUint16(i + 4, Endian.little),
        ));
      }
    }
    final sourceDd = editor.section(source, 'DD2 ', stride: 8)?.payload;
    final pending = <int>[];
    final terrain = _grid(result, 'MTXM'),
        underlying = doodads.isEmpty ? null : _grid(result, 'TILE');
    for (final d in doodads) {
      final r = d.recipe, b = d.bounds;
      final nx = (b.x + dx) * 32 + r.centerOffsetX,
          ny = (b.y + dy) * 32 + r.centerOffsetY;
      if (occupiedCenters.contains((nx, ny))) {
        throw StateError('MIXED_CLIPBOARD_OVERLAY');
      }
      for (final c in r.footprint) {
        final at = ((b.y + dy + c.y) * w + b.x + dx + c.x) * 2,
            base = underlying!.getUint16(at, Endian.little);
        if ((c.requiredTileGroup != 0 && base >> 4 != c.requiredTileGroup) ||
            (c.writesTerrain && base == c.rawTileValue)) {
          throw StateError('MIXED_CLIPBOARD_UNDERLYING');
        }
        if (c.writesTerrain) {
          terrain.setUint16(at, c.rawTileValue!, Endian.little);
        }
      }
      final record = Uint8List.fromList(
        sourceDd!.sublist(d.recordIndex * 8, d.recordIndex * 8 + 8),
      );
      ByteData.sublistView(record)
        ..setUint16(2, nx, Endian.little)
        ..setUint16(4, ny, Endian.little);
      pending.addAll(record);
    }
    if (doodads.isNotEmpty) {
      result = _put(result, 'MTXM', terrain.buffer.asUint8List());
      result = _put(result, 'DD2 ', [
        ...?editor.section(target, 'DD2 ', stride: 8)?.payload,
        ...pending,
      ]);
    }
    if (objects != null) {
      result = objects!.paste(
        result,
        x: x * 32 + objects!.anchorX - region.left * 32,
        y: y * 32 + objects!.anchorY - region.top * 32,
        locationStrings: locationStrings,
        includeLocations: includeLocations,
      );
    }
    layout(result, data, isom: isom);
    return result;
  }

  void _checkLocationReferences(RawChkDocument target, Map<int, int> mapped) {
    final names = {
      for (final record in objects?.records['MRGN'] ?? <List<int>>[])
        ByteData.sublistView(
          Uint8List.fromList(record),
        ).getUint16(16, Endian.little),
    }..remove(0);
    if (names.isEmpty) return;
    final old = const ChkStringViewDecoder().decode(source),
        now = const ChkStringViewDecoder().decode(target);
    final a = [...old.legacyTables, ...old.extendedTables],
        b = [...now.legacyTables, ...now.extendedTables];
    if (old.hasBlockingDiagnostics ||
        now.hasBlockingDiagnostics ||
        a.length != 1 ||
        b.length != 1) {
      throw StateError('MIXED_CLIPBOARD_STRING_REFERENCE');
    }
    for (final id in names) {
      final before = a.single.entryForId(id)?.rawBytes,
          after = b.single.entryForId(mapped[id] ?? id)?.rawBytes;
      // Same ID is insufficient after string-table compaction or replacement.
      if (before == null ||
          after == null ||
          before.length != after.length ||
          !Iterable.generate(
            before.length,
          ).every((i) => before[i] == after[i])) {
        throw StateError('MIXED_CLIPBOARD_STRING_REFERENCE');
      }
    }
  }

  RawChkDocument cut({int? rawReplacement, int? fillShape}) {
    final isom = profile == MixedClipboardProfile.isom;
    var result = objects == null
        ? source
        : ChkEditingClipboard.cut(_withoutDoodads(source), selected);
    final dd = editor.section(source, 'DD2 ', stride: 8);
    if (dd != null) {
      final records = dd.payload;
      final removed = doodads.map((d) => d.recordIndex).toSet();
      result = _put(result, 'DD2 ', [
        for (var i = 0; i < records.length ~/ 8; i++)
          if (!removed.contains(i)) ...records.sublist(i * 8, i * 8 + 8),
      ]);
    }
    final (w, _) = editor.dimensions(source);
    final m = _grid(source, 'MTXM'),
        t = tile == null ? null : _grid(source, 'TILE');
    for (final d in doodads) {
      for (final c in d.recipe.footprint) {
        final at = ((d.bounds.y + c.y) * w + d.bounds.x + c.x) * 2;
        if (c.writesTerrain) {
          m.setUint16(at, t!.getUint16(at, Endian.little), Endian.little);
        }
      }
    }
    result = _put(result, 'MTXM', m.buffer.asUint8List());
    if (isom) {
      final shape = data.brush!.shapes[fillShape];
      if (shape == null || shape.links.toSet().length != 1) {
        throw StateError('MIXED_CLIPBOARD_FILL');
      }
      final overlay = IsomDoodadOverlay.read(
        result,
        data.recipes,
        allowDisabled: true,
      );
      result = overlay.restore(
        const IsomTerrainPaint()
            .previewShapes(
              overlay.base,
              data.catalog!,
              data.brush!,
              assignments: {for (final d in shapes.keys) d: fillShape!},
              solveRegion: true,
            )
            .result,
      );
    } else {
      if (rawReplacement == null ||
          rawReplacement < 0 ||
          rawReplacement > 65535 ||
          !Iterable.generate(m.lengthInBytes ~/ 2).any(
            (i) => (t ?? m).getUint16(i * 2, Endian.little) == rawReplacement,
          )) {
        throw StateError('MIXED_CLIPBOARD_FILL');
      }
      for (final name in ['MTXM', if (tile != null) 'TILE']) {
        final b = _grid(result, name);
        for (var y = region.top; y <= region.bottom; y++) {
          for (var x = region.left; x <= region.right; x++) {
            b.setUint16((y * w + x) * 2, rawReplacement, Endian.little);
          }
        }
        result = _put(result, name, b.buffer.asUint8List());
      }
    }
    layout(result, data, isom: isom);
    return result;
  }
}
