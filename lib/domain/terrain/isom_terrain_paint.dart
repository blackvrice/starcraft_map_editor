// Diamond propagation adapted from Chkdraft (MIT), revision
// 32d27861b16dda0b0f3d95e34bad894ea4efb2c3. See docs/licenses/Chkdraft.txt.
import 'dart:collection';
import 'dart:typed_data';
import '../chk/raw_chk_document.dart';
import '../chk/typed/chk_editor_terrain.dart';
import 'isom_terrain_conversion.dart';
import 'isom_terrain_fill.dart';

typedef IsomDiamond = (int, int);

final class IsomDiamondShape {
  IsomDiamondShape(this.index, this.terrainType, List<int> links)
    : links = List.unmodifiable(links) {
    if (index < 1 ||
        index > 2047 ||
        terrainType < 1 ||
        terrainType > 63 ||
        links.length != 4 ||
        links.any((v) => v < 1 || v > 258)) {
      throw ArgumentError('Invalid diamond shape.');
    }
  }
  final int index, terrainType;
  final List<int> links;
}

final class IsomBrushCatalog {
  IsomBrushCatalog(List<IsomDiamondShape> shapes, Map<int, List<int>> neighbors)
    : shapes = Map.unmodifiable({for (final s in shapes) s.index: s}),
      neighbors = Map.unmodifiable({
        for (final e in neighbors.entries)
          e.key: List<int>.unmodifiable(e.value),
      }) {
    if (this.shapes.length != shapes.length) {
      throw ArgumentError('Duplicate diamond shape.');
    }
  }
  final Map<int, IsomDiamondShape> shapes;
  final Map<int, List<int>> neighbors;
}

class IsomTerrainPaint {
  const IsomTerrainPaint();
  static const _offsets = [(-1, -1), (1, -1), (1, 1), (-1, 1)];

  /// The closest diamond to a tile, with deterministic tie breaking.
  static IsomDiamond diamondAtTile(int x, int y) {
    RangeError.checkNotNegative(x, 'x');
    RangeError.checkNotNegative(y, 'y');
    final a = (x + 1) ~/ 2;
    return (a, y + ((a + y).isOdd ? 1 : 0));
  }

  IsomFillPreview preview(
    RawChkDocument source,
    IsomTerrainCatalog catalog,
    IsomBrushCatalog brush, {
    required int solidShape,
    required Set<IsomDiamond> diamonds,
    int seed = 0,
  }) {
    // Validate the original before introducing new shapes.
    const IsomTerrainConverter().preview(
      source,
      catalog,
      seed: seed,
      requireKnownSourcePairs: true,
    );
    final report = const ChkEditorTerrainDecoder().decode(source);
    final w = report.width!, h = report.height!, columns = w ~/ 2 + 1;
    final section = report.sections.singleWhere(
      (s) => s.rawSection.name == 'ISOM',
    );
    final data = ByteData.sublistView(
      Uint8List.fromList(section.rawSection.payload),
    );
    final shape = brush.shapes[solidShape];
    if (shape == null || shape.links.toSet().length != 1 || diamonds.isEmpty) {
      throw StateError(
        'Choose a verified terrain and a nonempty brush region.',
      );
    }
    bool inside(IsomDiamond d) =>
        d.$1 >= 0 &&
        d.$1 < columns &&
        d.$2 >= 0 &&
        d.$2 <= h &&
        (d.$1 + d.$2).isEven;
    Iterable<(int, int, int)> cells(IsomDiamond d) sync* {
      final x = d.$1, y = d.$2;
      final rects = [
        (x - 1, y - 1, 2),
        (x, y - 1, 0),
        (x, y, 0),
        (x - 1, y, 1),
      ];
      final other = [3, 3, 1, 2];
      for (var q = 0; q < 4; q++) {
        final r = rects[q];
        if (r.$1 < 0 || r.$1 >= columns || r.$2 < 0 || r.$2 > h) continue;
        final base = (r.$2 * columns + r.$1) * 8;
        yield (base + r.$3 * 2, q, 0);
        yield (base + other[q] * 2, q, 1);
      }
    }

    final values = <IsomDiamond, int>{};
    for (var y = 0; y <= h; y++) {
      for (var x = y & 1; x < columns; x += 2) {
        final d = (x, y);
        final indices = {
          for (final c in cells(d))
            (data.getUint16(c.$1, Endian.little) & 0x7ffe) >> 4,
        };
        if (indices.length != 1 || !brush.shapes.containsKey(indices.single)) {
          throw StateError(
            'Inconsistent or unsupported ISOM diamond at $x,$y.',
          );
        }
        values[d] = indices.single;
      }
    }
    bool matches(IsomDiamondShape a, int q, IsomDiamondShape b) =>
        a.links[q] == b.links[(q + 2) % 4] &&
        (a.links[q] < 255 || a.terrainType == b.terrainType);
    void validate() {
      for (final e in values.entries) {
        for (var q = 0; q < 4; q++) {
          final o = _offsets[q], n = (e.key.$1 + o.$1, e.key.$2 + o.$2);
          if (inside(n) &&
              !matches(brush.shapes[e.value]!, q, brush.shapes[values[n]]!)) {
            throw StateError('Unresolved diamond connection at ${e.key}/$q.');
          }
        }
      }
    }

    validate();
    final originalValues = Map<IsomDiamond, int>.of(values);
    final locked = <IsomDiamond>{};
    final visited = <IsomDiamond>{};
    final queue = Queue<IsomDiamond>();
    final ordered = diamonds.toList()
      ..sort(
        (a, b) => a.$2 == b.$2 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );
    for (final d in ordered) {
      if (!inside(d)) throw RangeError('Brush diamond outside the map.');
      values[d] = solidShape;
      locked.add(d);
    }
    void enqueue(IsomDiamond d) {
      for (final o in _offsets) {
        final n = (d.$1 + o.$1, d.$2 + o.$2);
        if (inside(n) && !locked.contains(n)) queue.add(n);
      }
    }

    for (final d in ordered) {
      enqueue(d);
    }
    int mappedType(int start, int destination) {
      final pending = Queue<int>()..add(start);
      final first = {start: start};
      while (pending.isNotEmpty) {
        final t = pending.removeFirst();
        for (final n in brush.neighbors[t] ?? <int>[]) {
          if (first.containsKey(n)) continue;
          first[n] = t == start ? n : first[t]!;
          if (n == destination) return first[n]!;
          pending.add(n);
        }
      }
      return first[destination] ?? 0;
    }

    final all = brush.shapes.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    while (queue.isNotEmpty) {
      final d = queue.removeFirst();
      if (locked.contains(d) || !visited.add(d)) continue;
      final neighbors = <int, IsomDiamondShape>{};
      final fixed = <int>{};
      var maxType = 0;
      for (var q = 0; q < 4; q++) {
        final o = _offsets[q], n = (d.$1 + o.$1, d.$2 + o.$2);
        if (!inside(n)) continue;
        neighbors[q] = brush.shapes[values[n]]!;
        if (locked.contains(n)) {
          fixed.add(q);
          if (neighbors[q]!.terrainType > maxType) {
            maxType = neighbors[q]!.terrainType;
          }
        }
      }
      var best = values[d]!, bestCount = 0;
      final previous = brush.shapes[best]!;
      final mapped = mappedType(maxType, previous.terrainType);
      if (maxType != 0 &&
          maxType != previous.terrainType &&
          (mapped == 0 || !all.any((s) => s.terrainType == mapped))) {
        throw StateError(
          'The required boundary is unavailable in the local catalog.',
        );
      }
      final priorities = [mapped, maxType, 0];
      for (final type in priorities) {
        for (final candidate in all.where(
          (s) =>
              type == 0 ? s.links.toSet().length == 1 : s.terrainType == type,
        )) {
          var count = 0, invalid = false;
          for (final e in neighbors.entries) {
            if (matches(candidate, e.key, e.value)) {
              count++;
            } else if (fixed.contains(e.key)) {
              invalid = true;
              break;
            }
          }
          if (!invalid && count > bestCount) {
            bestCount = count;
            best = candidate.index;
          }
        }
      }
      if (best != values[d]) {
        values[d] = best;
        locked.add(d);
        enqueue(d);
      }
    }
    validate();
    var changed = false;
    for (final d in locked) {
      if (values[d] == originalValues[d]) continue;
      for (final c in cells(d)) {
        final old = data.getUint16(c.$1, Endian.little);
        final next = (old & 0x8001) | (values[d]! << 4) | (c.$2 * 4 + c.$3 * 2);
        if (old != next) {
          data.setUint16(c.$1, next, Endian.little);
          changed = true;
        }
      }
    }
    final staged = changed
        ? source.replaceSection(
            section.sectionIndex,
            section.rawSection.withPayload(data.buffer.asUint8List()),
          )
        : source;
    final result = const IsomTerrainConverter().preview(
      staged,
      catalog,
      seed: seed,
    );
    return IsomFillPreview.fromPaint(source, result, isomChanged: changed);
  }
}
