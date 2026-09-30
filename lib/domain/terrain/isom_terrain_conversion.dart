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

/// First supported conversion subset: verified, unstacked left/right tile pairs.
/// Unknown edges, stacked terrain, doodads and raw overrides fail atomically.
class IsomTerrainConverter {
  const IsomTerrainConverter();
  IsomConversionPreview preview(
    RawChkDocument source,
    IsomTerrainCatalog catalog, {
    required int seed,
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
      if (!pair.isUnstacked) continue;
      final key = (
        pair.links[0],
        pair.links[1],
        pair.links[2],
        pair.links[3],
        pair.links.any((v) => v >= 48) ? pair.terrainType : 0,
      );
      (candidates[key] ??= []).add(pair);
    }
    for (final list in candidates.values) {
      list.sort((a, b) => a.leftGroup.compareTo(b.leftGroup));
    }
    final bytes = tile.rawSection.payload;
    var changes = 0;
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
          if (e.link >= 48 && e.terrainType != 0) type = e.terrainType;
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
          throw StateError('No verified unstacked tile pair at ($x,$y).');
        }
        final oldLeft = tile.tileAt(x * 2, y),
            oldRight = tile.tileAt(x * 2 + 1, y);
        IsomTilePair? selected;
        var member = oldLeft & 15;
        for (final p in choices) {
          if (oldLeft ~/ 16 == p.leftGroup &&
              oldRight ~/ 16 == p.leftGroup + 1 &&
              (oldRight & 15) == member &&
              p.members.contains(member)) {
            selected = p;
            break;
          }
        }
        if (selected == null) {
          final hash = _mix(seed, x, y);
          selected = choices[hash % choices.length];
          member = selected
              .members[(hash ~/ choices.length) % selected.members.length];
        }
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

  int _mix(int seed, int x, int y) {
    var value = seed;
    for (final v in [x, y]) {
      value = ((value ^ v) * 16777619) & 0xffffffff;
    }
    return value;
  }
}
