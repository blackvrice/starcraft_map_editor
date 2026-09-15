import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_impact_pane.dart';
import '../fixtures/eud_impact_fixture.dart';

class _Catalog implements PlacementCatalogController {
  final events = StreamController<PlacementCatalogState>.broadcast(sync: true);
  @override
  int weaponReferenceEpoch = 0;
  Completer<WeaponReferenceSnapshot>? pending;
  bool fail = false;
  @override
  Stream<PlacementCatalogState> get changes => events.stream;
  @override
  Future<WeaponReferenceSnapshot> loadWeaponReferences() async {
    if (fail) throw StateError('Incomplete weapon reference coverage');
    return pending != null
        ? pending!.future
        : WeaponReferenceSnapshot(
            impactReferences(),
            weaponReferenceEpoch,
            'test build 1',
          );
  }

  void invalidate() {
    weaponReferenceEpoch++;
    events.add(PlacementCatalogState());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EudProject _project(int weapon) => EudProject(
  mapPath: 'test.scx',
  mapSha256: 'a' * 64,
  overrides: [
    EudOverride(field: 'weapon.maxRange', targetId: weapon, value: 64),
  ],
);

void main() {
  testWidgets(
    'shows names, refreshes override targets and invalidates stale references',
    (tester) async {
      final catalog = _Catalog();
      addTearDown(catalog.events.close);
      Future<void> show(int weapon) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EudImpactPane(project: _project(weapon), catalog: catalog),
          ),
        ),
      );
      await show(5);
      expect(find.textContaining('Impact unknown:'), findsOneWidget);
      await tester.tap(find.text('Load weapon impact'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Terran Marine (#0)'), findsOneWidget);
      expect(
        find.textContaining('Via subunits: Terran Vulture (#2)'),
        findsOneWidget,
      );
      await show(129);
      expect(
        find.textContaining('Direct units: None in static references'),
        findsOneWidget,
      );
      catalog.invalidate();
      await tester.pump();
      expect(find.textContaining('Impact unknown:'), findsOneWidget);
      expect(find.textContaining('Reference source:'), findsNothing);
      catalog.fail = true;
      await tester.tap(find.text('Load weapon impact'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Incomplete weapon reference coverage'),
        findsOneWidget,
      );
      expect(find.textContaining('Direct units: None'), findsNothing);
    },
  );
  testWidgets(
    'discards pending result after source changes and after disposal',
    (tester) async {
      final catalog = _Catalog()
        ..pending = Completer<WeaponReferenceSnapshot>();
      addTearDown(catalog.events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EudImpactPane(project: _project(5), catalog: catalog),
          ),
        ),
      );
      await tester.tap(find.text('Load weapon impact'));
      catalog.invalidate();
      catalog.pending!.complete(
        WeaponReferenceSnapshot(impactReferences(), 0, 'stale'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Reference source:'), findsNothing);
      catalog.pending = Completer<WeaponReferenceSnapshot>();
      await tester.tap(find.text('Load weapon impact'));
      await tester.pumpWidget(const SizedBox());
      catalog.pending!.complete(
        WeaponReferenceSnapshot(impactReferences(), 1, 'disposed'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
