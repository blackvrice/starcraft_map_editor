import 'dart:convert';
import '../chk/chk_basic_editing.dart';
import '../chk/chk_mixed_clipboard.dart';
import '../chk/chk_raw_terrain_clipboard.dart';
import '../chk/raw_chk_document.dart';
import 'isom_terrain_conversion.dart';
import 'isom_terrain_paint.dart';

enum TerrainBrushProfile { raw, isom }

/// Only bounded numeric metadata is portable; never a source map or game image.
final class UserTerrainBrush {
  UserTerrainBrush._(
    this.name,
    this.profile,
    this.tileset,
    this.revision,
    this.width,
    this.height,
    this.raw,
    this.shapes,
  );
  static const maxBytes = 512 * 1024;
  static const rawRevision = 'raw-mtxm-v1';
  final String name, revision;
  final TerrainBrushProfile profile;
  final int tileset, width, height;
  final List<int> raw;
  final Map<IsomDiamond, int> shapes;
  static const _editor = ChkBasicEditing();

  static String checkedName(String value) {
    final name = value.trim();
    if (name.isEmpty ||
        name.length > 80 ||
        name.codeUnits.any((c) => c < 32 || c == 127)) {
      throw const FormatException('BRUSH_NAME');
    }
    return name;
  }

  static int _tileset(RawChkDocument doc) {
    _editor.dimensions(doc);
    final era = _editor.section(doc, 'ERA ');
    if (era == null ||
        era.payload.length != 2 ||
        era.payload[0] > 7 ||
        era.payload[1] != 0) {
      throw StateError('BRUSH_TILESET');
    }
    return era.payload[0];
  }

  static UserTerrainBrush capture(
    RawChkDocument doc, {
    required String name,
    required ClipboardRegion region,
    required TerrainBrushProfile profile,
    IsomTerrainCatalog? catalog,
    IsomBrushCatalog? brush,
  }) {
    final checked = checkedName(name), tileset = _tileset(doc);
    // A stored terrain-only stamp must not contain hidden doodad composites.
    final dd = _editor.section(doc, 'DD2 ', stride: 8);
    if (dd != null && dd.payload.isNotEmpty) {
      throw StateError('BRUSH_DOODAD_UNSUPPORTED');
    }
    final isom = profile == TerrainBrushProfile.isom;
    if (isom != doc.sections.any((s) => s.name == 'ISOM')) {
      throw StateError('BRUSH_PROFILE');
    }
    if (!isom) {
      final clip = ChkRawTerrainClipboard.capture(
        doc,
        left: region.left,
        top: region.top,
        right: region.right,
        bottom: region.bottom,
      );
      return UserTerrainBrush._(
        checked,
        profile,
        tileset,
        rawRevision,
        clip.width,
        clip.height,
        clip.values,
        const {},
      );
    }
    if (catalog == null || brush == null || catalog.tileset != tileset) {
      throw StateError('BRUSH_CATALOG');
    }
    final clip = ChkMixedClipboard.capture(
      doc,
      region: region,
      profile: MixedClipboardProfile.isom,
      kinds: {},
      overlays: {},
      data: MixedClipboardData(recipes: [], catalog: catalog, brush: brush),
    );
    return UserTerrainBrush._(
      checked,
      profile,
      tileset,
      catalog.revision,
      region.width,
      region.height,
      const [],
      Map.unmodifiable({
        for (final e in clip.shapes.entries)
          (e.key.$1 - region.left ~/ 2, e.key.$2 - region.top): e.value,
      }),
    );
  }

  String encode() => jsonEncode({
    'version': 1,
    'name': name,
    'profile': profile.name,
    'tileset': tileset,
    'revision': revision,
    'width': width,
    'height': height,
    'raw': raw,
    'shapes': [
      for (final e in shapes.entries) [e.key.$1, e.key.$2, e.value],
    ],
  });

  static UserTerrainBrush decode(String source) {
    if (source.length > maxBytes || utf8.encode(source).length > maxBytes) {
      throw const FormatException('BRUSH_SIZE');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        value.length != 9 ||
        value['version'] != 1 ||
        value['version'] is! int ||
        value['name'] is! String ||
        value['revision'] is! String ||
        value['width'] is! int ||
        value['height'] is! int ||
        value['tileset'] is! int ||
        value['raw'] is! List ||
        value['shapes'] is! List) {
      throw const FormatException('BRUSH_SCHEMA');
    }
    final name = checkedName(value['name'] as String),
        revision = value['revision'] as String,
        width = value['width'] as int,
        height = value['height'] as int,
        tileset = value['tileset'] as int;
    final profile = switch (value['profile']) {
      'raw' => TerrainBrushProfile.raw,
      'isom' => TerrainBrushProfile.isom,
      _ => throw const FormatException('BRUSH_PROFILE'),
    };
    if (width < 1 ||
        width > 256 ||
        height < 1 ||
        height > 256 ||
        tileset < 0 ||
        tileset > 7 ||
        revision.isEmpty ||
        revision.length > 256 ||
        revision.codeUnits.any((c) => c < 32 || c == 127)) {
      throw const FormatException('BRUSH_METADATA');
    }
    final raw = value['raw'] as List, entries = value['shapes'] as List;
    if (profile == TerrainBrushProfile.raw) {
      if (revision != rawRevision ||
          entries.isNotEmpty ||
          raw.length != width * height ||
          raw.any((v) => v is! int || v < 0 || v > 65535)) {
        throw const FormatException('BRUSH_RAW_GRID');
      }
    } else if (raw.isNotEmpty ||
        width % 4 != 0 ||
        height.isOdd ||
        entries.isEmpty ||
        entries.length > width * height ~/ 4) {
      throw const FormatException('BRUSH_ISOM_GRID');
    }
    final shapes = <IsomDiamond, int>{};
    for (final row in entries) {
      if (row is! List || row.length != 3 || row.any((v) => v is! int)) {
        throw const FormatException('BRUSH_DIAMOND');
      }
      final x = row[0] as int, y = row[1] as int, shape = row[2] as int;
      if (x < 1 ||
          x >= width ~/ 2 ||
          y < 1 ||
          y >= height ||
          (x + y).isOdd ||
          shape < 1 ||
          shape > 2047 ||
          shapes.containsKey((x, y))) {
        throw const FormatException('BRUSH_DIAMOND');
      }
      shapes[(x, y)] = shape;
    }
    // Capture stores every complete interior diamond, not a sparse guessed mask.
    if (profile == TerrainBrushProfile.isom &&
        shapes.length !=
            [
              for (var y = 1; y < height; y++)
                for (var x = 1; x < width ~/ 2; x++)
                  if ((x + y).isEven) (x, y),
            ].length) {
      throw const FormatException('BRUSH_ISOM_GRID');
    }
    return UserTerrainBrush._(
      name,
      profile,
      tileset,
      revision,
      width,
      height,
      List<int>.unmodifiable(raw),
      Map.unmodifiable(shapes),
    );
  }

  RawChkDocument preview(
    RawChkDocument target, {
    required int x,
    required int y,
    IsomTerrainCatalog? catalog,
    IsomBrushCatalog? brush,
    Set<int> solidShapes = const {},
    bool mirrorX = false,
    bool mirrorY = false,
  }) {
    final (w, h) = _editor.dimensions(target);
    if (_tileset(target) != tileset ||
        x < 0 ||
        y < 0 ||
        x + width > w ||
        y + height > h) {
      throw StateError('BRUSH_DESTINATION');
    }
    final isom = profile == TerrainBrushProfile.isom;
    if (isom != target.sections.any((s) => s.name == 'ISOM')) {
      throw StateError('BRUSH_PROFILE');
    }
    if (!isom) {
      if (mirrorX || mirrorY) throw StateError('BRUSH_RAW_MIRROR_UNSUPPORTED');
      return ChkRawTerrainClipboard.fromValues(
        width: width,
        height: height,
        values: raw,
      ).paste(target, x: x, y: y);
    }
    if (catalog == null ||
        brush == null ||
        catalog.tileset != tileset ||
        catalog.revision != revision ||
        x % 4 != 0 ||
        y.isOdd ||
        shapes.values.any((s) => !brush.shapes.containsKey(s))) {
      throw StateError('BRUSH_CATALOG_OR_ALIGNMENT');
    }
    if ((mirrorX || mirrorY) &&
        shapes.values.any(
          (s) =>
              !solidShapes.contains(s) ||
              brush.shapes[s]!.links.toSet().length != 1,
        )) {
      throw StateError('BRUSH_DIRECTION_UNVERIFIED');
    }
    // Reflection acts on semantic diamond centers, then the existing solver
    // regenerates directional transitions. Raw tile IDs are never reflected.
    final painted = const IsomTerrainPaint().previewShapes(
      target,
      catalog,
      brush,
      assignments: {
        for (final e in shapes.entries)
          (
            (mirrorX ? width ~/ 2 - e.key.$1 : e.key.$1) + x ~/ 2,
            (mirrorY ? height - e.key.$2 : e.key.$2) + y,
          ): e.value,
      },
      solveRegion: true,
    );
    // A semantic no-op must retain the user's existing random tile variants.
    if (!painted.isomChanged) return target;
    final result = painted.result;
    final same =
        result.sections.length == target.sections.length &&
        Iterable<int>.generate(result.sections.length).every((i) {
          if (identical(result.sections[i], target.sections[i])) return true;
          if (result.sections[i].name != target.sections[i].name) return false;
          final a = result.sections[i].payload, b = target.sections[i].payload;
          return a.length == b.length &&
              Iterable<int>.generate(a.length).every((j) => a[j] == b[j]);
        });
    return same ? target : result;
  }
}
