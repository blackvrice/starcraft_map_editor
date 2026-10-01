import 'dart:collection';
import 'isom_terrain_paint.dart';
import 'isom_terrain_conversion.dart';

/// Arc consistency with deterministic backtracking for new resize territory.
/// Assigned source diamonds are singletons and can never be modified.
Map<IsomDiamond, int> solveIsomRegion(
  Map<IsomDiamond, int> original,
  Map<IsomDiamond, int> assigned,
  IsomBrushCatalog catalog,
  IsomTerrainCatalog tiles,
  int width,
  int height,
) {
  final compiled = _compile(catalog, tiles);
  final shapes = compiled.shapes,
      indices = compiled.indices,
      bits = compiled.bits;
  final all = (BigInt.one << shapes.length) - BigInt.one;
  const offsets = [(-1, -1), (1, -1), (1, 1), (-1, 1)];
  final supports = compiled.supports;
  final masks = {
    for (final d in original.keys)
      d: assigned.containsKey(d) ? bits[indices[assigned[d]]!] : all,
  };
  final trail = <(IsomDiamond, BigInt)>[];
  final buckets = SplayTreeMap<int, Set<IsomDiamond>>();
  final counts = <BigInt, int>{};
  int count(BigInt mask) => counts.putIfAbsent(mask, () {
    var n = 0;
    while (mask != BigInt.zero) {
      mask &= mask - BigInt.one;
      n++;
    }
    return n;
  });
  void bucket(IsomDiamond d, BigInt mask, bool add) {
    final n = count(mask);
    if (n <= 1) return;
    if (add) {
      (buckets[n] ??= <IsomDiamond>{}).add(d);
    } else {
      buckets[n]?.remove(d);
      if (buckets[n]?.isEmpty == true) buckets.remove(n);
    }
  }

  for (final e in masks.entries) {
    bucket(e.key, e.value, true);
  }
  void change(IsomDiamond d, BigInt mask, {bool remember = true}) {
    final old = masks[d]!;
    if (remember) trail.add((d, old));
    bucket(d, old, false);
    masks[d] = mask;
    bucket(d, mask, true);
  }

  final supportCache = <(int, BigInt), BigInt>{};
  BigInt supported(int q, BigInt mask) =>
      supportCache.putIfAbsent((q, mask), () {
        var result = BigInt.zero;
        while (mask != BigInt.zero) {
          final bit = mask & -mask;
          result |= supports[q][bit.bitLength - 1];
          mask ^= bit;
        }
        return result;
      });
  bool propagate(Iterable<IsomDiamond> initial) {
    final pending = Queue<IsomDiamond>()..addAll(initial);
    final queued = initial.toSet();
    while (pending.isNotEmpty) {
      final d = pending.removeFirst();
      queued.remove(d);
      for (var q = 0; q < 4; q++) {
        final o = offsets[q], n = (d.$1 + o.$1, d.$2 + o.$2);
        final old = masks[n];
        if (old == null) continue;
        final rx = d.$1 - ((q == 0 || q == 3) ? 1 : 0),
            ry = d.$2 - (q < 2 ? 1 : 0);
        final interior = rx >= 0 && rx < width ~/ 2 && ry >= 0 && ry < height;
        final next = old & supported(q + (interior ? 4 : 0), masks[d]!);
        if (next == old) continue;
        if (next == BigInt.zero) return false;
        change(n, next);
        if (queued.add(n)) pending.add(n);
      }
    }
    return true;
  }

  if (!propagate(assigned.keys)) {
    throw StateError('No compatible ISOM boundary around the retained map.');
  }
  trail.clear();
  final decisions = <_Decision>[];
  var attempts = 0;
  while (buckets.isNotEmpty) {
    final d = buckets[buckets.firstKey()]!.first;
    final candidates = <BigInt>[];
    var mask = masks[d]!;
    final preferred = bits[indices[original[d]]!];
    if ((mask & preferred) != BigInt.zero) {
      candidates.add(preferred);
      mask ^= preferred;
    }
    while (mask != BigInt.zero) {
      final bit = mask & -mask;
      candidates.add(bit);
      mask ^= bit;
    }
    decisions.add(_Decision(d, candidates, trail.length));
    var success = false;
    while (decisions.isNotEmpty) {
      final decision = decisions.last;
      while (trail.length > decision.trailStart) {
        final (at, old) = trail.removeLast();
        change(at, old, remember: false);
      }
      if (decision.next == decision.candidates.length) {
        decisions.removeLast();
        continue;
      }
      if (++attempts > 100000) {
        throw StateError(
          'ISOM resize boundary search exceeded its safety limit.',
        );
      }
      change(decision.diamond, decision.candidates[decision.next++]);
      if (propagate([decision.diamond])) {
        success = true;
        break;
      }
    }
    if (!success) {
      throw StateError('No compatible ISOM boundary around the retained map.');
    }
    if (supportCache.length > 8192) supportCache.clear();
  }
  return {
    for (final e in masks.entries) e.key: shapes[e.value.bitLength - 1].index,
  };
}

class _Decision {
  _Decision(this.diamond, this.candidates, this.trailStart);
  final IsomDiamond diamond;
  final List<BigInt> candidates;
  final int trailStart;
  int next = 0;
}

final _compiled = Expando<_Connections>();

class _Connections {
  _Connections(this.brush, this.shapes, this.indices, this.bits, this.supports);
  final IsomBrushCatalog brush;
  final List<IsomDiamondShape> shapes;
  final Map<int, int> indices;
  final List<BigInt> bits;
  final List<List<BigInt>> supports;
}

_Connections _compile(IsomBrushCatalog brush, IsomTerrainCatalog tiles) {
  final cached = _compiled[tiles];
  if (cached != null && identical(cached.brush, brush)) return cached;
  final shapes = brush.shapes.values.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  final indices = {for (var i = 0; i < shapes.length; i++) shapes[i].index: i};
  final bits = List.generate(shapes.length, (i) => BigInt.one << i);
  final edges = {for (final e in tiles.edges) e.value: e};
  final pairs = {
    for (final p in tiles.pairs)
      if (p.stackConnections[0] == 0 && p.stackConnections[2] == 0)
        (
          p.links[0],
          p.links[1],
          p.links[2],
          p.links[3],
          p.links.any((v) => v > 48) ? p.terrainType : 0,
        ),
  };
  bool renderable(int q, int a, int b) {
    a <<= 4;
    b <<= 4;
    final words = switch (q) {
      0 => [b | 8, b | 10, a, a | 2],
      1 => [a | 4, b | 12, b | 14, a | 6],
      2 => [a | 8, a | 10, b, b | 2],
      _ => [b | 4, a | 12, a | 14, b | 6],
    };
    final resolved = [for (final w in words) edges[w]];
    if (resolved.any((e) => e == null)) return false;
    final types = {
      for (final e in resolved)
        if (e!.link > 48 && e.terrainType != 0) e.terrainType,
    };
    if (types.length > 1) return false;
    return pairs.contains((
      resolved[0]!.link,
      resolved[1]!.link,
      resolved[2]!.link,
      resolved[3]!.link,
      types.isEmpty ? 0 : types.single,
    ));
  }

  final supports = List.generate(
    8,
    (_) => List.filled(shapes.length, BigInt.zero),
  );
  for (var q = 0; q < 4; q++) {
    for (var i = 0; i < shapes.length; i++) {
      for (var j = 0; j < shapes.length; j++) {
        if (shapes[i].links[q] != shapes[j].links[(q + 2) % 4] ||
            (shapes[i].links[q] >= 255 &&
                shapes[i].terrainType != shapes[j].terrainType)) {
          continue;
        }
        supports[q][i] |= bits[j];
        if (renderable(q, shapes[i].index, shapes[j].index)) {
          supports[q + 4][i] |= bits[j];
        }
      }
    }
  }
  return _compiled[tiles] = _Connections(
    brush,
    shapes,
    indices,
    bits,
    supports,
  );
}
