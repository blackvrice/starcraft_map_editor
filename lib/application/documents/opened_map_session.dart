import '../../domain/chk/chk.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/map_archive_gateway.dart';

class OpenedMapSession {
  OpenedMapSession({
    required this.extractedMap,
    required this.rawDocument,
    required this.metadataViews,
    required Iterable<EditorDiagnostic> diagnostics,
  }) : diagnostics = List.unmodifiable(diagnostics);

  final ExtractedMap extractedMap;
  final RawChkDocument rawDocument;
  final ChkMetadataViews metadataViews;
  final List<EditorDiagnostic> diagnostics;

  String get sourcePath => extractedMap.sourcePath;

  MapArchiveMetadata get archiveMetadata => extractedMap.metadata;

  int get scenarioChkSizeBytes => extractedMap.scenarioChkBytes.length;

  bool get requiresRestrictedEditing =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);
}
