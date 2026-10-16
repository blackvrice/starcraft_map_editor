import '../../domain/chk/chk.dart';
import '../../domain/chk/chk_mixed_clipboard.dart';
import '../../domain/terrain/isom_doodad_overlay.dart';
import '../documents/isom_fill_controller.dart';
import '../documents/open_map_controller.dart';
import '../documents/opened_map_session.dart';
import '../layers/map_layer_controller.dart';
import '../terrain/solid_isom_catalog_builder.dart';

final class MixedClipboardPreview {
  MixedClipboardPreview._(
    this.source,
    this.result,
    this.isCut,
    this.sections,
    this.session,
  );
  final RawChkDocument source, result;
  final bool isCut;
  final Set<String> sections;
  final OpenedMapSession session;
  int get changedSections => sections.length;
}

/// One immutable payload per document; only an issued preview can be applied.
final class MixedClipboardController {
  MixedClipboardController({
    required this.maps,
    required this.layers,
    required this.apply,
  });
  final OpenMapController maps;
  final MapLayerController layers;
  final bool Function(RawChkDocument, RawChkDocument, String) apply;
  MixedClipboardData? _data;
  IsomFillController? _loader;
  SolidIsomCatalog? _catalog;
  int _loadRevision = 0;
  ChkMixedClipboard? _clipboard;
  Object? _token;
  MixedClipboardPreview? _preview;

  bool get hasData =>
      _catalog != null && _loader!.isClipboardCatalogCurrent(_catalog!);
  SolidIsomCatalog? get catalog => hasData ? _catalog : null;
  ChkMixedClipboard? get clipboard =>
      identical(_token, maps.state.session?.extractedMap) &&
          (_clipboard?.data.catalog == null || hasData)
      ? _clipboard
      : null;
  MixedClipboardPreview? get preview => _preview;
  RawChkDocument get _source {
    final s = maps.state.session, p = maps.operationProgressController.current;
    if (s == null ||
        s.requiresRestrictedEditing ||
        maps.editHistory.isTransactionActive ||
        (p != null && !p.isTerminal)) {
      throw StateError('MIXED_CLIPBOARD_BUSY');
    }
    return s.rawDocument;
  }

  MixedClipboardData get _currentData =>
      hasData ? _data! : MixedClipboardData(recipes: []);

  Future<void> load(IsomFillController loader) async {
    clear();
    _catalog = null;
    _data = null;
    _loader = null;
    final revision = ++_loadRevision;
    final source = _source;
    final catalog = await loader.load();
    if (revision != _loadRevision ||
        !identical(source, _source) ||
        !loader.isClipboardCatalogCurrent(catalog)) {
      throw StateError('MIXED_CLIPBOARD_STALE');
    }
    _loader = loader;
    _catalog = catalog;
    _data = MixedClipboardData(
      recipes: loader.doodadRecipes,
      catalog: catalog.catalog,
      brush: catalog.brush,
    );
  }

  List<IsomDoodadInstance> doodads(
    ClipboardRegion region,
    MixedClipboardProfile profile,
  ) =>
      ChkMixedClipboard.layout(
            _source,
            _currentData,
            isom: profile == MixedClipboardProfile.isom,
          )
          .where(
            (d) => region.intersects(
              d.bounds.x,
              d.bounds.y,
              d.bounds.width,
              d.bounds.height,
            ),
          )
          .toList(growable: false);

  void invalidatePreview() => _preview = null;
  void clear() {
    _clipboard = null;
    _token = null;
    invalidatePreview();
  }

  void _unlocked(Set<String> sections) {
    for (final name in sections) {
      final layer = switch (name) {
        'UNIT' => MapLayerType.units,
        'THG2' => MapLayerType.sprites,
        'MRGN' => MapLayerType.locations,
        'DD2 ' => MapLayerType.doodads,
        _ => MapLayerType.terrain,
      };
      if (!layers.state.statusOf(layer).isSelectable) {
        throw StateError('MIXED_CLIPBOARD_LAYER: ${layer.name}');
      }
    }
  }

  ChkMixedClipboard capture({
    required ClipboardRegion region,
    required MixedClipboardProfile profile,
    required Set<String> kinds,
    required Map<int, int> overlays,
  }) {
    clear();
    final captured = ChkMixedClipboard.capture(
      _source,
      region: region,
      profile: profile,
      kinds: kinds,
      overlays: overlays,
      data: _currentData,
    );
    _unlocked(captured.sections);
    _token = maps.state.session!.extractedMap;
    return _clipboard = captured;
  }

  MixedClipboardPreview _issue(
    RawChkDocument source,
    RawChkDocument result,
    bool cut,
  ) {
    final sections = <String>{};
    for (final s in result.sections) {
      final old = source.sections.where((v) => v.name == s.name).toList();
      if (old.length == 1 && _equal(old.single.payload, s.payload)) {
        continue;
      }
      if (!source.sections.contains(s)) sections.add(s.name);
    }
    _unlocked(clipboard!.sections);
    final before = maps.state.session!;
    final session = OpenedMapSession(
      extractedMap: before.extractedMap,
      rawDocument: result,
      metadataViews: maps.metadataViewDecoder.decode(result),
      stringViews: maps.stringViewDecoder.decode(result),
      terrainViews: maps.terrainViewDecoder.decode(result),
      objectViews: maps.objectViewDecoder.decode(result),
      sourceFingerprint: before.sourceFingerprint,
      diagnostics: before.diagnostics,
      resourceEdits: before.resourceEdits,
    );
    return _preview = MixedClipboardPreview._(
      source,
      sections.isEmpty ? source : result,
      cut,
      Set.unmodifiable(sections),
      session,
    );
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  MixedClipboardPreview previewPaste({required int x, required int y}) {
    invalidatePreview();
    final source = _source, clip = clipboard;
    if (clip == null) throw StateError('MIXED_CLIPBOARD_STALE');
    return _issue(source, clip.paste(source, x: x, y: y), false);
  }

  MixedClipboardPreview previewCut({int? rawReplacement, int? fillShape}) {
    invalidatePreview();
    final source = _source, clip = clipboard;
    if (clip == null || !identical(clip.source, source)) {
      throw StateError('MIXED_CLIPBOARD_STALE');
    }
    return _issue(
      source,
      clip.cut(rawReplacement: rawReplacement, fillShape: fillShape),
      true,
    );
  }

  bool applyPreview(MixedClipboardPreview preview) {
    if (!identical(preview, _preview) ||
        clipboard == null ||
        !identical(preview.source, _source)) {
      throw StateError('MIXED_CLIPBOARD_STALE');
    }
    _unlocked(clipboard!.sections);
    final changed = apply(
      preview.source,
      preview.result,
      preview.isCut ? 'Cut mixed region' : 'Paste mixed region',
    );
    invalidatePreview();
    return changed;
  }
}
