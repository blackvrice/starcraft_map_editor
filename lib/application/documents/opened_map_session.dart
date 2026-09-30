import '../../domain/chk/typed/chk_editor_terrain.dart';
import '../../domain/chk/chk.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/map_archive_gateway.dart';
import '../ports/map_file_fingerprint_gateway.dart';
import 'pending_map_resources.dart';

class OpenedMapSession {
  OpenedMapSession({
    required this.extractedMap,
    required this.rawDocument,
    required this.metadataViews,
    required this.stringViews,
    required this.terrainViews,
    required this.objectViews,
    required this.sourceFingerprint,
    required Iterable<EditorDiagnostic> diagnostics,
    Map<String, List<int>?> resourceEdits = const {},
  }) : resourceEdits = PendingMapResources(resourceEdits),
       diagnostics = List.unmodifiable(diagnostics) {
    if ((extractedMap.sourcePath == null) != (sourceFingerprint == null)) {
      throw ArgumentError('Only a new map may omit its source fingerprint.');
    }
  }

  final Map<String, List<int>?> resourceEdits;

  final ExtractedMap extractedMap;
  final RawChkDocument rawDocument;

  // Cache per immutable session; raw edits/Undo create a fresh session report.
  late final editorTerrain = const ChkEditorTerrainDecoder().decode(
    rawDocument,
  );
  final ChkMetadataViews metadataViews;
  final ChkStringViews stringViews;
  final ChkTerrainViews terrainViews;
  final ChkObjectViews objectViews;
  final MapFileFingerprint? sourceFingerprint;
  final List<EditorDiagnostic> diagnostics;

  bool get isNewMap => extractedMap.sourcePath == null;

  String? get sourcePath => extractedMap.sourcePath;

  MapArchiveMetadata get archiveMetadata => extractedMap.metadata;

  int get scenarioChkSizeBytes => extractedMap.scenarioChkBytes.length;

  bool get isDirty =>
      isNewMap || rawDocument.isDirty || resourceEdits.isNotEmpty;

  bool get requiresRestrictedEditing =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);
}
