import 'dart:async';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_project_workspace.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import '../fixtures/eud_project_workspace_fixture.dart';

void main() {
  late EudWorkspaceFixture fixture;
  setUp(() {
    fixture = EudWorkspaceFixture();
  });
  tearDown(() => fixture.dispose());

  test(
    'unsaved and restricted maps are rejected without changing the project',
    () async {
      await fixture.maps.open();
      final clean = fixture.maps.state.session!;
      final raw = clean.rawDocument;
      final index = raw.sections.length - 1;
      for (final dirty in [true, false]) {
        final session = OpenedMapSession(
          extractedMap: clean.extractedMap,
          rawDocument: dirty
              ? raw.replaceSection(
                  index,
                  raw.sections[index].withPayload([1, 0]),
                )
              : raw,
          metadataViews: clean.metadataViews,
          stringViews: clean.stringViews,
          terrainViews: clean.terrainViews,
          objectViews: clean.objectViews,
          sourceFingerprint: clean.sourceFingerprint,
          diagnostics: dirty
              ? []
              : [
                  const EditorDiagnostic(
                    code: 'TEST_RESTRICTED',
                    message: 'restricted',
                    severity: DiagnosticSeverity.error,
                    stage: DiagnosticStage.validate,
                  ),
                ],
        );
        fixture.maps.adoptEditedSession(session);
        expect(
          fixture.workspace.binding,
          dirty ? EudMapBinding.unsavedMap : EudMapBinding.restrictedMap,
        );
        await expectLater(fixture.workspace.createFromMap(), throwsStateError);
        expect(fixture.projects.project, isNull);
      }
    },
  );

  test(
    'create verifies current disk map and save cancellation preserves dirty state',
    () async {
      await expectLater(fixture.workspace.createFromMap(), throwsStateError);
      await fixture.maps.open();
      await fixture.workspace.createFromMap();
      expect(fixture.workspace.binding, EudMapBinding.matched);
      expect(fixture.projects.isDirty, isTrue);
      fixture.savePath = null;
      await fixture.workspace.saveAs();
      expect(fixture.projects.isDirty, isTrue);
      expect(fixture.writes, 0);
      fixture.savePath = r'C:\Maps\saved.eud.json';
      await fixture.workspace.saveAs();
      expect(fixture.projects.isDirty, isFalse);
      expect(fixture.writes, 1);
    },
  );

  test(
    'untrusted project reference is not accessed and mismatch needs explicit rebind',
    () async {
      await fixture.maps.open();
      fixture.openPath = 'other.eud.json';
      fixture.files[fixture.openPath!] = EudProject(
        mapPath: r'Z:\untrusted\other.scx',
        mapSha256: 'b' * 64,
      );
      await fixture.workspace.open();
      await fixture.workspace.verify();
      expect(fixture.workspace.binding, EudMapBinding.mismatch);
      expect(
        fixture.reads.every((path) => path == r'C:\Maps\base.scx'),
        isTrue,
      );
      await fixture.workspace.rebind();
      expect(fixture.workspace.binding, EudMapBinding.matched);
      expect(fixture.projects.isDirty, isTrue);
      fixture.projects.undo();
      expect(fixture.workspace.binding, EudMapBinding.unchecked);
      expect(fixture.projects.project!.mapPath, r'Z:\untrusted\other.scx');
    },
  );

  test(
    'disk change and failed verification never retain matched status',
    () async {
      await fixture.maps.open();
      await fixture.workspace.createFromMap();
      fixture.hash = 'b' * 64;
      await expectLater(fixture.workspace.verify(), throwsStateError);
      expect(fixture.workspace.binding, EudMapBinding.diskChanged);
      fixture.failFingerprint = true;
      await expectLater(fixture.workspace.verify(), throwsStateError);
      expect(fixture.workspace.binding, EudMapBinding.unchecked);
    },
  );

  test('stale fingerprint result cannot rebind a changed project', () async {
    await fixture.maps.open();
    await fixture.workspace.createFromMap();
    fixture.pending = Completer<MapFileFingerprint>();
    final result = fixture.workspace.verify();
    fixture.projects.rebindMap(
      mapPath: r'C:\Maps\other.scx',
      mapSha256: 'b' * 64,
    );
    fixture.pending!.complete(fixture.snapshot);
    await expectLater(result, throwsStateError);
    expect(fixture.workspace.binding, EudMapBinding.unchecked);
  });
}
