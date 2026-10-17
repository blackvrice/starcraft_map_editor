import '../../domain/chk/chk.dart';
import '../../domain/chk/chk_mixed_clipboard.dart';
import '../../domain/chk/chk_mixed_document_transfer.dart';
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
    this.transfer,
    this.expectedSession,
  );
  final RawChkDocument source, result;
  final bool isCut;
  final Set<String> sections;
  final OpenedMapSession session;
  final ChkMixedDocumentTransferPlan? transfer;
  final OpenedMapSession expectedSession;
  int get changedSections => sections.length;
}

/// A tool-owned immutable payload; only its issued preview can be applied.
final class MixedClipboardController {
  MixedClipboardController({
    required this.maps,
    required this.layers,
    required this.apply,
  }) : targetMaps = null,
       targetLayers = null,
       isAvailable = null;
  MixedClipboardController.betweenDocuments({
    required this.maps,
    required this.layers,
    required this.targetMaps,
    required this.targetLayers,
    required this.isAvailable,
    required this.apply,
  }) {
    if (targetMaps == null ||
        targetLayers == null ||
        identical(maps, targetMaps)) {
      throw ArgumentError('Mixed transfer needs two independent documents.');
    }
  }
  final OpenMapController maps;
  final MapLayerController layers;
  final OpenMapController? targetMaps;
  final MapLayerController? targetLayers;
  final bool Function()? isAvailable;
  bool get isCrossDocument => targetMaps != null;
  final bool Function(RawChkDocument, RawChkDocument, String) apply;
  MixedClipboardData? _data;
  IsomFillController? _loader;
  SolidIsomCatalog? _catalog;
  int _loadRevision = 0;
  ChkMixedClipboard? _clipboard;
  Object? _token;
  MixedClipboardPreview? _preview;
  OpenedMapSession? _capturedSource;
  bool _disposed = false;

  bool get hasData =>
      !_disposed &&
      _catalog != null &&
      _loader!.isClipboardCatalogCurrent(_catalog!);
  SolidIsomCatalog? get catalog => hasData ? _catalog : null;
  ChkMixedClipboard? get clipboard =>
      !_disposed &&
          isAvailable?.call() != false &&
          (!isCrossDocument ||
              identical(_capturedSource, maps.state.session)) &&
          identical(_token, maps.state.session?.extractedMap) &&
          (_clipboard?.data.catalog == null || hasData)
      ? _clipboard
      : null;
  MixedClipboardPreview? get preview => _preview;
  bool get isPreviewCurrent =>
      _preview != null &&
      clipboard != null &&
      (!isCrossDocument ||
          identical(_preview!.expectedSession, targetMaps!.state.session)) &&
      identical(
        _preview!.source,
        (targetMaps ?? maps).state.session?.rawDocument,
      );
  RawChkDocument get _source {
    final s = maps.state.session, p = maps.operationProgressController.current;
    if (_disposed ||
        isAvailable?.call() == false ||
        s == null ||
        s.requiresRestrictedEditing ||
        maps.editHistory.isTransactionActive ||
        (p != null && !p.isTerminal)) {
      throw StateError('MIXED_CLIPBOARD_BUSY');
    }
    return s.rawDocument;
  }

  RawChkDocument get _destination {
    if (targetMaps == null) return _source;
    _source;
    final s = targetMaps!.state.session,
        p = targetMaps!.operationProgressController.current;
    if (s == null ||
        s.requiresRestrictedEditing ||
        targetMaps!.editHistory.isTransactionActive ||
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
    _capturedSource = null;
    invalidatePreview();
  }

  void dispose() {
    _disposed = true;
    _loadRevision++;
    clear();
    _catalog = null;
    _data = null;
    _loader = null;
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
      if (targetLayers?.state.statusOf(layer).isSelectable == false) {
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
    _capturedSource = maps.state.session;
    return _clipboard = captured;
  }

  MixedClipboardPreview _issue(
    RawChkDocument source,
    RawChkDocument result,
    bool cut, {
    ChkMixedDocumentTransferPlan? transfer,
  }) {
    final sections = <String>{};
    for (final s in result.sections) {
      final old = source.sections.where((v) => v.name == s.name).toList();
      if (old.length == 1 && _equal(old.single.payload, s.payload)) {
        continue;
      }
      if (!source.sections.contains(s)) sections.add(s.name);
    }
    _unlocked(clipboard!.sections);
    final before = (targetMaps ?? maps).state.session!;
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
      transfer,
      before,
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
    final source = _destination, clip = clipboard;
    if (clip == null) throw StateError('MIXED_CLIPBOARD_STALE');
    final transfer = isCrossDocument
        ? ChkMixedDocumentTransferPlan.preview(clip, source, x: x, y: y)
        : null;
    return _issue(
      source,
      transfer?.result ?? clip.paste(source, x: x, y: y),
      false,
      transfer: transfer,
    );
  }

  MixedClipboardPreview previewCut({int? rawReplacement, int? fillShape}) {
    if (isCrossDocument) {
      throw StateError('MIXED_CLIPBOARD_CROSS_CUT_UNSUPPORTED');
    }
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
        (isCrossDocument &&
            !identical(preview.expectedSession, targetMaps!.state.session)) ||
        !identical(preview.source, _destination)) {
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
