import '../chk/raw_chk_document.dart';
import '../chk/typed/chk_editor_terrain.dart';

/// Supplied by a versioned local-data provider, not inferred from tile numbers.
final class IsomEdgeConnection {
  IsomEdgeConnection({
    required this.value,
    required this.link,
    required this.terrainType,
  }) {
    if (value < 0 ||
        value > 0x7ffe ||
        value.isOdd ||
        link < 0 ||
        link > 63 ||
        terrainType < 0 ||
        terrainType > 63) {
      throw ArgumentError('Invalid canonical ISOM connection.');
    }
  }
  final int value, link, terrainType;
}

final class IsomTilePair {
  IsomTilePair({
    required this.leftGroup,
    required this.terrainType,
    required List<int> links,
    required List<int> stackConnections,
    required List<int> members,
  }) : links = List.unmodifiable(links),
       stackConnections = List.unmodifiable(stackConnections),
       members = List.unmodifiable(members.toList()..sort()) {
    if (leftGroup < 0 ||
        leftGroup > 4094 ||
        leftGroup.isOdd ||
        terrainType < 0 ||
        terrainType > 63 ||
        links.length != 4 ||
        links.any((v) => v < 0 || v > 63) ||
        stackConnections.length != 4 ||
        stackConnections.any((v) => v < 0 || v > 65535) ||
        members.isEmpty ||
        members.length > 16 ||
        members.toSet().length != members.length ||
        members.any((v) => v < 0 || v > 15)) {
      throw ArgumentError('Invalid validated tile pair.');
    }
  }
  final int leftGroup, terrainType;
  final List<int> links, stackConnections, members;
  bool get isUnstacked => stackConnections.every((v) => v == 0);
}

/// Numeric projection only. Raw CV5/assets and unsupported shape guesses stay out.
final class IsomTerrainCatalog {
  IsomTerrainCatalog({
    required this.tileset,
    required this.revision,
    required List<IsomEdgeConnection> edges,
    required List<IsomTilePair> pairs,
  }) : edges = List.unmodifiable(edges),
       pairs = List.unmodifiable(pairs) {
    if (tileset < 0 ||
        tileset > 7 ||
        revision.trim().isEmpty ||
        edges.isEmpty ||
        edges.length > 16384 ||
        pairs.isEmpty ||
        pairs.length > 2048 ||
        edges.map((e) => e.value).toSet().length != edges.length ||
        pairs.map((p) => p.leftGroup).toSet().length != pairs.length) {
      throw ArgumentError('Invalid or ambiguous ISOM catalog.');
    }
  }
  final int tileset;
  final String revision;
  final List<IsomEdgeConnection> edges;
  final List<IsomTilePair> pairs;
}

final class IsomConversionPreview {
  const IsomConversionPreview._(
    this.source,
    this.result,
    this.changedTileCount,
    this.catalogRevision,
    this.seed,
  );
  final RawChkDocument source, result;
  final int changedTileCount, seed;
  final String catalogRevision;
}

typedef _ConnectionKey = (int, int, int, int, int);

/// Verified left/right pairs with a globally consistent vertical stack path.
/// Unknown edges, horizontal stacks, doodads and raw overrides fail atomically.
class IsomTerrainConverter {
  const IsomTerrainConverter();
  IsomConversionPreview preview(
    RawChkDocument source,
    IsomTerrainCatalog catalog, {
    required int seed,
    bool requireKnownSourcePairs = false,
  }) {
    RangeError.checkValueInInterval(seed, 0, 0xffffffff, 'seed');
    final report = const ChkEditorTerrainDecoder().decode(source);
    final width = report.width, height = report.height;
    if (width == null ||
        height == null ||
        width.isOdd ||
        width > 256 ||
        height > 256 ||
        report.duplicateNames.isNotEmpty ||
        report.hasProtectionMarker ||
        report.hasDoodads) {
      throw StateError(
        'Conversion requires a unique even-width grid up to 256, without protection or doodads.',
      );
    }
    final eras = source.sections.where((s) => s.name == 'ERA ').toList();
    if (eras.length != 1 ||
        eras.single.payload.length != 2 ||
        eras.single.payload[0] != catalog.tileset ||
        eras.single.payload[1] != 0) {
      throw StateError('The catalog tileset does not match the source.');
    }
    EditorTerrainSection grid(String name) {
      final matches = report.sections
          .where((s) => s.rawSection.name == name)
          .toList();
      if (matches.length != 1 || !matches.single.hasValidStructure) {
        throw StateError('A unique structurally valid $name grid is required.');
      }
      return matches.single;
    }

    final isom = grid('ISOM'), tile = grid('TILE');
    grid('MTXM');
    if (report.differentTileCount != 0) {
      throw StateError(
        'MTXM has raw overrides. Conversion would overwrite them.',
      );
    }
    final edges = {for (final e in catalog.edges) e.value: e};
    final candidates = <_ConnectionKey, List<IsomTilePair>>{};
    for (final pair in catalog.pairs) {
      if (pair.stackConnections[0] != 0 || pair.stackConnections[2] != 0) {
        continue;
      }
      final key = (
        pair.links[0],
        pair.links[1],
        pair.links[2],
        pair.links[3],
        pair.links.any((v) => v > 48) ? pair.terrainType : 0,
      );
      (candidates[key] ??= []).add(pair);
    }
    for (final list in candidates.values) {
      list.sort((a, b) => a.leftGroup.compareTo(b.leftGroup));
    }
    final bytes = tile.rawSection.payload;
    if (requireKnownSourcePairs) {
      final pairs = {for (final p in catalog.pairs) p.leftGroup: p};
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x += 2) {
          final left = tile.tileAt(x, y), right = tile.tileAt(x + 1, y);
          final p = pairs[left ~/ 16];
          if (p == null ||
              right ~/ 16 != p.leftGroup + 1 ||
              (left & 15) != (right & 15) ||
              !p.members.contains(left & 15)) {
            throw StateError(
              'Unsupported existing tile pair at ($x,$y); preserved.',
            );
          }
        }
      }
    }
    var changes = 0;
    final cells = List.generate(height, (_) => <List<IsomTilePair>>[]);
    // Right and bottom padding rectangles are not output cells, but must also
    // reference known values; never silently accept an unknown border.
    for (var y = 0; y < isom.rows!; y++) {
      for (var x = 0; x < isom.columns!; x++) {
        final r = isom.isomAt(x, y);
        final resolved = <IsomEdgeConnection>[];
        for (final raw in [r.left, r.top, r.right, r.bottom]) {
          final edge =
              edges[raw & 0x7ffe]; // Lookup only; original flags are kept.
          if (edge == null) {
            throw StateError('Unknown ISOM side at ($x,$y): $raw.');
          }
          resolved.add(edge);
        }
        if (x == width ~/ 2 || y == height) continue;
        var type = 0;
        for (final e in resolved) {
          if (e.link > 48 && e.terrainType != 0) {
            if (type != 0 && type != e.terrainType) {
              throw StateError('Mixed hard-link terrain types at ($x,$y).');
            }
            type = e.terrainType;
          }
        }
        final key = (
          resolved[0].link,
          resolved[1].link,
          resolved[2].link,
          resolved[3].link,
          type,
        );
        final choices = candidates[key];
        if (choices == null || choices.isEmpty) {
          throw StateError('No verified tile pair at ($x,$y).');
        }
        cells[y].add(choices);
      }
    }
    // Solve the whole column before writing any tile. Local greedy choices
    // can select a stack row that leaves no compatible member below it.
    for (var x = 0; x < width ~/ 2; x++) {
      final column = _column(
        [for (var y = 0; y < height; y++) cells[y][x]],
        tile,
        x,
        seed,
      );
      for (var y = 0; y < height; y++) {
        final selected = column[y].pair, member = column[y].member;
        final values = [
          selected.leftGroup * 16 + member,
          (selected.leftGroup + 1) * 16 + member,
        ];
        for (var i = 0; i < 2; i++) {
          final at = (y * width + x * 2 + i) * 2;
          if (bytes[at] != (values[i] & 255) ||
              bytes[at + 1] != (values[i] >> 8)) {
            changes++;
          }
          bytes[at] = values[i] & 255;
          bytes[at + 1] = values[i] >> 8;
        }
      }
    }
    var result = source;
    if (changes > 0) {
      for (var i = 0; i < source.sections.length; i++) {
        final s = source.sections[i];
        if (s.name == 'TILE' || s.name == 'MTXM') {
          result = result.replaceSection(i, s.withPayload(bytes));
        }
      }
    }
    return IsomConversionPreview._(
      source,
      result,
      changes,
      catalog.revision,
      seed,
    );
  }

  List<_StackPath> _column(
    List<List<IsomTilePair>> rows,
    EditorTerrainSection tile,
    int x,
    int seed,
  ) {
    var previous = <(int, int), _StackPath>{};
    for (var y = 0; y < rows.length; y++) {
      final next = <(int, int), _StackPath>{};
      final states = [
        for (final p in rows[y])
          for (final m in p.members) (p, m),
      ];
      final offset = _mix(seed, x, y) % states.length;
      for (var i = 0; i < states.length; i++) {
        final (p, m) = states[(i + offset) % states.length];
        final top = p.stackConnections[1], bottom = p.stackConnections[3];
        final parent = previous[(top, top == 0 ? -1 : m)];
        // Map edges may clip a stack, but interior seams must match exactly.
        if (y > 0 && parent == null) continue;
        final cost =
            (parent?.cost ?? 0) +
            (tile.tileAt(x * 2, y) == p.leftGroup * 16 + m ? 0 : 1) +
            (tile.tileAt(x * 2 + 1, y) == (p.leftGroup + 1) * 16 + m ? 0 : 1);
        final key = (bottom, bottom == 0 ? -1 : m);
        if (next[key] == null || cost < next[key]!.cost) {
          next[key] = _StackPath(p, m, cost, parent);
        }
      }
      if (next.isEmpty) {
        throw StateError('No compatible vertical stack at ($x,$y).');
      }
      previous = next;
    }
    final paths = previous.values.toList()
      ..sort((a, b) => a.cost.compareTo(b.cost));
    var path = paths.first;
    final result = <_StackPath>[path];
    while (path.parent != null) {
      path = path.parent!;
      result.add(path);
    }
    return result.reversed.toList();
  }

  int _mix(int seed, int x, int y) {
    var value = seed;
    for (final v in [x, y]) {
      value = ((value ^ v) * 16777619) & 0xffffffff;
    }
    return value;
  }
}

final class _StackPath {
  const _StackPath(this.pair, this.member, this.cost, this.parent);
  final IsomTilePair pair;
  final int member, cost;
  final _StackPath? parent;
}
