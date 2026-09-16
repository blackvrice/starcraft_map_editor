import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/settings/eud_tool_settings_controller.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  test(
    'persists external choice, restores it, and explicitly clears to default',
    () async {
      final store = InMemorySettingsStore();
      final inspector = TestInspector();
      final controller = EudToolSettingsController(
        store: store,
        inspector: inspector,
        bundledPath: r'C:\bundle',
      );
      addTearDown(controller.dispose);
      await controller.selectExternal(r'C:\external');
      expect(
        inspector.requests.single.selectedCandidate!.source,
        EudToolPathSource.userSettings,
      );
      expect(controller.state.result!.isReady, false);
      expect(
        controller
            .inspectionRequest(projectProfilePath: r'C:\project')
            .selectedCandidate!
            .path,
        r'C:\project',
      );
      final restored = EudToolSettingsController(
        store: store,
        inspector: inspector,
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.state.path, r'C:\external');
      await controller.useDefault();
      expect(
        inspector.requests.last.selectedCandidate!.source,
        EudToolPathSource.bundled,
      );
      expect(
        await store.readString(EudToolSettingsController.settingsKey),
        isNull,
      );
    },
  );

  test(
    'busy inspection cannot be overwritten and exceptions clear prior result',
    () async {
      final inspector = TestInspector();
      final controller = EudToolSettingsController(
        store: InMemorySettingsStore(),
        inspector: inspector,
      );
      addTearDown(controller.dispose);
      final pending = Completer<EudToolInspectionResult>();
      inspector.pending = pending.future;
      final first = controller.selectExternal(r'C:\first');
      await Future<void>.delayed(Duration.zero);
      await controller.selectExternal(r'C:\second');
      expect(controller.state.path, r'C:\first');
      expect(controller.state.busy, true);
      pending.complete(TestInspector.failure());
      await first;
      inspector.pending = Future.error(StateError('inspection failed'));
      await controller.refresh();
      expect(controller.state.busy, false);
      expect(controller.state.result, isNull);
      expect(controller.state.error, contains('inspection failed'));
    },
  );

  test(
    'store failure retains selected path and does not inspect a new one',
    () async {
      final store = FailingStore();
      final inspector = TestInspector();
      final controller = EudToolSettingsController(
        store: store,
        inspector: inspector,
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.selectExternal(r'C:\new');
      expect(controller.state.path, r'C:\old');
      expect(controller.state.error, contains('write failed'));
      expect(inspector.requests, hasLength(1));
    },
  );
}

class TestInspector implements EudToolInspector {
  final requests = <EudToolInspectionRequest>[];
  Future<EudToolInspectionResult>? pending;
  static EudToolInspectionResult failure() => EudToolInspectionResult.failure(
    diagnostics: const [
      EditorDiagnostic(
        code: 'EUD_TOOL_COMPANION_MISSING',
        message: 'Incomplete installation',
        severity: DiagnosticSeverity.error,
        stage: DiagnosticStage.validate,
        remediation: 'Re-extract the complete official release.',
        rawDetails: 'missing=lib/freezeMpq.pyd',
      ),
    ],
  );
  @override
  Future<EudToolInspectionResult> inspect(
    EudToolInspectionRequest request,
  ) async {
    requests.add(request);
    return pending == null ? failure() : await pending!;
  }
}

class FailingStore extends InMemorySettingsStore {
  FailingStore() : super({EudToolSettingsController.settingsKey: r'C:\old'});
  @override
  Future<void> writeString(String key, String value) async =>
      throw StateError('write failed');
}
