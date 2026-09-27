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
       diagnostics = List.unmodifiable(diagnostics);

  final Map<String, List<int>?> resourceEdits;

  final ExtractedMap extractedMap;
  final RawChkDocument rawDocument;
  final ChkMetadataViews metadataViews;
  final ChkStringViews stringViews;
  final ChkTerrainViews terrainViews;
  final ChkObjectViews objectViews;
  final MapFileFingerprint sourceFingerprint;
  final List<EditorDiagnostic> diagnostics;

  String get sourcePath => extractedMap.sourcePath;

  MapArchiveMetadata get archiveMetadata => extractedMap.metadata;

  int get scenarioChkSizeBytes => extractedMap.scenarioChkBytes.length;

  bool get isDirty => rawDocument.isDirty || resourceEdits.isNotEmpty;

  bool get requiresRestrictedEditing =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);
}
