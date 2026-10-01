import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_dat_gateway.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_field_editor.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_impact_pane.dart';
import 'package:starcraft_map_editor/domain/eud/eud_field_manifest.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import '../fixtures/eud_project_workspace_fixture.dart';
import '../fixtures/eud_dat_fixture.dart';

class _Gateway implements EudDatGateway {
  @override
  void cancel(String id) {}
  @override
  Future<EudDatReadResult> read({
    required String operationId,
    required String installationPath,
  }) async => EudDatReadResult(source: syntheticDatSource());
}

class _Catalog implements PlacementCatalogController {
  final events = StreamController<PlacementCatalogState>.broadcast(sync: true);
  @override
  EudDatSource? eudData;
  @override
  final EudDatGateway eudDatGateway = _Gateway();
  @override
  Stream<PlacementCatalogState> get changes => events.stream;
  @override
  int weaponReferenceEpoch = 0;
  @override
  Future<EudDatSource> loadEudData() async {
    eudData = syntheticDatSource();
    events.add(PlacementCatalogState());
    return eudData!;
  }

  @override
  Future<WeaponReferenceSnapshot> loadWeaponReferences() async =>
      WeaponReferenceSnapshot(
        syntheticDatSource().snapshot.weaponIndex(),
        weaponReferenceEpoch,
        'synthetic',
      );
  @override
  Future<PlacementCatalogItem?> loadUnitPreview(int unit) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'default lookup is read-only, input copy requires staging, stale defaults disappear',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = EudWorkspaceFixture();
      addTearDown(f.dispose);
      await f.maps.open();
      await f.workspace.createFromMap();
      final catalog = _Catalog();
      addTearDown(catalog.events.close);
      final original = f.projects.project,
          map = f.maps.state.session!.rawDocument;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showEudFieldEditor(
                  context,
                  controller: f.projects,
                  catalog: catalog,
                ),
                child: const Text('edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eud-category-weapon')));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButton<EudFieldDefinition>>(
            find.byKey(const Key('eud-extension-field')),
          )
          .onChanged!(EudFieldManifest.find('weapon.cooldown'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('eud-dat-load')));
      await tester.tap(find.byKey(const Key('eud-dat-load')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Local DAT: 15'), findsOneWidget);
      expect(f.projects.project, same(original));
      await tester.tap(find.byKey(const Key('eud-dat-use-default')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('eud-extension-number')))
            .controller!
            .text,
        '15',
      );
      catalog.eudData = null;
      catalog.weaponReferenceEpoch++;
      catalog.events.add(PlacementCatalogState());
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('eud-dat-use-default')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const Key('eud-extension-stage')));
      await tester.tap(find.byKey(const Key('eud-extension-stage')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eud-extension-apply')));
      await tester.pumpAndSettle();
      expect(f.projects.project!.overrides.single.value, 15);
      expect(f.maps.state.session!.rawDocument, same(map));
      f.projects.undo();
      expect(f.projects.project!.overrides, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'graphics impact contrasts original and planned direct/reachable references',
    (tester) async {
      final c = syntheticDatColumns();
      c['unit.flingy']![0] = 1;
      c['flingy.sprite']![1] = 10;
      c['sprite.image']![10] = 20;
      final catalog = _Catalog()..eudData = syntheticDatSource(c);
      addTearDown(catalog.events.close);
      final project = EudProject(
        mapPath: 'test.scx',
        mapSha256: 'a' * 64,
        overrides: [
          EudOverride(field: 'sprite.image', targetId: 10, value: 21),
          EudOverride(field: 'image.isTurnable', targetId: 20, value: true),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EudImpactPane(project: project, catalog: catalog),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              w.data!.contains('Original users: Terran Marine (#0)'),
        ),
        findsNWidgets(2),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data!.contains('Planned users: None'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              w.data!.contains('Direct planned references:'),
        ),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
