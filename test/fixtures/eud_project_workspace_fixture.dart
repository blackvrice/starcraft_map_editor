import 'dart:async';
import 'dart:typed_data';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_project_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_project_workspace.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_project_picker.dart';
import 'package:starcraft_map_editor/application/ports/eud_project_store.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

class EudWorkspaceFixture
    implements
        EudProjectStore,
        EudProjectPicker,
        MapFileFingerprintGateway,
        MapFilePicker,
        MapArchiveGateway {
  EudWorkspaceFixture() {
    maps = OpenMapController(
      archiveGateway: this,
      filePicker: this,
      fingerprintGateway: this,
      recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
      operationProgressController: progress,
    );
    projects = EudProjectController(this);
    workspace = EudProjectWorkspace(
      projects: projects,
      maps: maps,
      picker: this,
    );
  }
  final progress = OperationProgressController();
  late final OpenMapController maps;
  late final EudProjectController projects;
  late final EudProjectWorkspace workspace;
  final files = <String, EudProject>{};
  String? openPath;
  String? savePath = r'C:\Maps\settings.eud.json';
  String hash = 'a' * 64;
  bool failFingerprint = false;
  Completer<MapFileFingerprint>? pending;
  int writes = 0;
  final reads = <String>[];

  MapFileFingerprint get snapshot => MapFileFingerprint(
    sizeBytes: 1024,
    modifiedAt: DateTime.utc(2026),
    sha256Digest: hash,
  );
  @override
  Future<MapFileFingerprint> fingerprint(String path) async {
    reads.add(path);
    if (failFingerprint) throw StateError('unreadable');
    return pending == null ? snapshot : pending!.future;
  }

  @override
  Future<EudProject> read(String path) async => files[path]!;
  @override
  Future<void> saveAs(String path, EudProject project) async {
    if (files.containsKey(path)) throw StateError('Choose a new project path.');
    writes++;
    files[path] = project;
  }

  @override
  Future<String?> openProject() async => openPath;
  @override
  Future<String?> saveProjectAs() async => savePath;
  @override
  Future<String?> pickMapPath() async => r'C:\Maps\base.scx';
  @override
  Future<String?> pickSaveMapPath({required String suggestedName}) async =>
      null;
  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async {
    final bytes = BytesBuilder();
    for (final entry in {
      'TYPE': [0x52, 0x41, 0x57, 0x53],
      'VER ': [206, 0],
      'IVER': [10, 0],
      'DIM ': [64, 0, 64, 0],
      'ERA ': [0, 0],
    }.entries) {
      final section = Uint8List(8 + entry.value.length);
      section.setRange(0, 4, entry.key.codeUnits);
      ByteData.sublistView(
        section,
      ).setUint32(4, entry.value.length, Endian.little);
      section.setRange(8, section.length, entry.value);
      bytes.add(section);
    }
    final chk = bytes.takeBytes();
    return MapArchiveOpenResult.success(
      map: ExtractedMap(
        sourcePath: request.sourcePath,
        scenarioChkBytes: chk,
        metadata: MapArchiveMetadata(
          archiveSizeBytes: 1024,
          formatVersion: 1,
          totalEntryCount: 1,
          listingComplete: true,
          entries: [
            MapArchiveEntryMetadata(
              path: MapArchiveEntryPaths.scenarioChk,
              uncompressedSizeBytes: chk.length,
              compressedSizeBytes: chk.length,
              flags: 0x80000000,
              locale: 0,
              nameIsSynthetic: false,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(
    MapArchiveWriteRequest request,
  ) => throw StateError('Map writes are not allowed in project tests.');
  @override
  Future<bool> cancel(String operationId) async => false;
  void dispose() {
    workspace.dispose();
    projects.dispose();
    maps.dispose();
    progress.dispose();
  }
}
