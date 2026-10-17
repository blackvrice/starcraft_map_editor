import '../../domain/assets/map_sound.dart';
import '../../domain/chk/chk_document_transfer.dart';
import '../../domain/chk/typed/chk_resource_editor.dart';
import '../documents/document_workspace_controller.dart';
import '../documents/opened_map_session.dart';
import '../documents/pending_map_resources.dart';
import '../layers/map_layer_controller.dart';
import 'object_editing_controller.dart';

final class DocumentTransferAccess {
  const DocumentTransferAccess(this.layers, this.editing);
  final MapLayerController layers;
  final ObjectEditingController editing;
}

final class DocumentTransferPreview<T> {
  DocumentTransferPreview._(
    this.source,
    this.target,
    this.sourceSession,
    this.targetSession,
    this.plan,
    this.resources,
  );
  final WorkspaceDocument<T> source, target;
  final OpenedMapSession sourceSession, targetSession;
  final ChkDocumentTransferPlan plan;
  final PendingMapResources resources;
}

/// Preview owns immutable CHK/resource snapshots, not live UI selection.
final class DocumentTransferController<T> {
  DocumentTransferController({required this.workspace, required this.access});
  final DocumentWorkspaceController<T> workspace;
  final DocumentTransferAccess Function(WorkspaceDocument<T>) access;
  DocumentTransferPreview<T>? _preview;
  int _request = 0;
  bool busy = false, _disposed = false;
  DocumentTransferPreview<T>? get preview => _preview;
  void invalidate() {
    _request++;
    _preview = null;
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }

  OpenedMapSession _session(WorkspaceDocument<T> document) {
    final session = document.maps.state.session;
    if (_disposed ||
        !workspace.contains(document) ||
        document.busy ||
        session == null ||
        session.requiresRestrictedEditing) {
      throw StateError('TRANSFER_DOCUMENT_BUSY');
    }
    return session;
  }

  void _layers(WorkspaceDocument<T> document, Set<String> sections) {
    final layers = access(document).layers;
    for (final section in sections) {
      final layer = switch (section) {
        'UNIT' => MapLayerType.units,
        'THG2' => MapLayerType.sprites,
        'MRGN' => MapLayerType.locations,
        _ => null,
      };
      if (layer != null && !layers.state.statusOf(layer).isSelectable) {
        throw StateError('TRANSFER_LAYER_LOCKED: ${layer.name}');
      }
    }
  }

  Future<DocumentTransferPreview<T>> prepare({
    required WorkspaceDocument<T> source,
    required WorkspaceDocument<T> target,
    Map<String, Set<int>> selected = const {},
    Set<int> triggers = const {},
    Set<int> briefings = const {},
    int offsetX = 0,
    int offsetY = 0,
    Map<int, int> owners = const {},
    OpenedMapSession? expectedSource,
  }) async {
    if (busy || identical(source, target)) {
      throw StateError('TRANSFER_DOCUMENT_BUSY');
    }
    invalidate();
    final request = _request;
    final beforeSource = _session(source), beforeTarget = _session(target);
    if (expectedSource != null && !identical(expectedSource, beforeSource)) {
      throw StateError('TRANSFER_STALE');
    }
    busy = true;
    try {
      final clip = ChkDocumentTransfer.capture(
        beforeSource.rawDocument,
        selected: selected,
        triggers: triggers,
        briefings: briefings,
      );
      final sections = clip.objects?.records.keys.toSet() ?? <String>{};
      _layers(source, sections);
      _layers(target, sections);
      final plan = clip.preview(
        beforeTarget.rawDocument,
        offsetX: offsetX,
        offsetY: offsetY,
        owners: owners,
      );
      final resources = {...beforeTarget.resourceEdits};
      final paths = clip.sounds.values.toSet();
      if (paths.isNotEmpty &&
          (!beforeTarget.archiveMetadata.listingComplete ||
              beforeTarget.archiveMetadata.entries.any(
                (e) => e.nameIsSynthetic,
              ))) {
        throw StateError('TRANSFER_ARCHIVE_LISTING');
      }
      // Do not merge or overwrite even byte-identical sound paths. All locale
      // variants, deleted pending paths and existing references remain owned.
      final reserved = <String>{
        ...beforeTarget.archiveMetadata.entries.map(
          (e) => e.path.replaceAll('/', '\\').toLowerCase(),
        ),
        ...beforeTarget.resourceEdits.keys.map((p) => p.toLowerCase()),
      };
      if (paths.isNotEmpty) {
        final table = ChkResourceEditor.table(beforeTarget.rawDocument);
        for (final entry in table.entries) {
          final raw = entry.rawBytes;
          if (raw == null || raw.any((b) => b > 127)) continue;
          try {
            reserved.add(
              MapSound.path(String.fromCharCodes(raw)).toLowerCase(),
            );
          } on FormatException {
            // Reserve valid paths even when their raw/EUD users are opaque.
          }
        }
      }
      final incoming = <String>{};
      for (final path in paths) {
        if (reserved.contains(path.toLowerCase()) ||
            !incoming.add(path.toLowerCase())) {
          throw StateError('TRANSFER_SOUND_CONFLICT: $path');
        }
        final matches = beforeSource.resourceEdits.keys
            .where((p) => p.toLowerCase() == path.toLowerCase())
            .toList();
        if (matches.length > 1) throw StateError('TRANSFER_SOUND_PATH');
        final pending = matches.firstOrNull;
        if (pending == null) {
          final entries = beforeSource.archiveMetadata.entries
              .where(
                (e) =>
                    e.path.replaceAll('/', '\\').toLowerCase() ==
                    path.toLowerCase(),
              )
              .toList();
          if (!beforeSource.archiveMetadata.listingComplete ||
              entries.length != 1 ||
              entries.single.locale != 0 ||
              entries.single.nameIsSynthetic) {
            throw StateError('TRANSFER_ARCHIVE_LISTING');
          }
        }
        final bytes = await access(source).editing.soundBytes(path);
        MapSound.validate(bytes);
        resources[path] = bytes;
        if (resources.length > 64 ||
            resources.values.fold(0, (n, b) => n + (b?.length ?? 0)) >
                64 * 1024 * 1024) {
          throw StateError('TRANSFER_RESOURCE_LIMIT');
        }
      }
      if (_disposed ||
          request != _request ||
          !identical(beforeSource, _session(source)) ||
          !identical(beforeTarget, _session(target))) {
        throw StateError('TRANSFER_STALE');
      }
      return _preview = DocumentTransferPreview._(
        source,
        target,
        beforeSource,
        beforeTarget,
        plan,
        PendingMapResources(resources),
      );
    } finally {
      busy = false;
    }
  }

  void apply(DocumentTransferPreview<T> preview) {
    if (_disposed ||
        busy ||
        !identical(preview, _preview) ||
        !identical(_session(preview.source), preview.sourceSession) ||
        !identical(_session(preview.target), preview.targetSession)) {
      throw StateError('TRANSFER_STALE');
    }
    final sections =
        preview.plan.clipboard.objects?.records.keys.toSet() ?? <String>{};
    _layers(preview.source, sections);
    _layers(preview.target, sections);
    access(preview.target).editing.applyDocumentTransfer(
      expectedDocument: preview.plan.target,
      updatedDocument: preview.plan.result,
      resourceEdits: preview.resources,
    );
    invalidate();
  }
}
