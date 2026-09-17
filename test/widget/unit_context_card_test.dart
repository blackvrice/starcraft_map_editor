import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/presentation/settings/unit_context_card.dart';
import '../fixtures/eud_impact_fixture.dart';

class _Catalog implements PlacementCatalogController {
  final events = StreamController<PlacementCatalogState>.broadcast(sync: true);
  final requests = <Completer<WeaponReferenceSnapshot>>[];
  @override
  int weaponReferenceEpoch = 0;
  @override
  Stream<PlacementCatalogState> get changes => events.stream;
  @override
  Future<PlacementCatalogItem?> loadUnitPreview(int unit) async => null;
  @override
  Future<WeaponReferenceSnapshot> loadWeaponReferences() {
    final result = Completer<WeaponReferenceSnapshot>();
    requests.add(result);
    return result.future;
  }

  void complete(int i) => requests[i].complete(
    WeaponReferenceSnapshot(
      impactReferences(),
      weaponReferenceEpoch,
      'fixture',
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'links ground then air, subunits and preserves selection for no weapon',
    (tester) async {
      final catalog = _Catalog();
      addTearDown(catalog.events.close);
      final weapons = <int>[];
      final units = <int>[];
      Widget card(int unit) => MaterialApp(
        home: Scaffold(
          body: UnitContextCard(
            unit: unit,
            catalog: catalog,
            onWeapon: weapons.add,
            onUnit: units.add,
          ),
        ),
      );
      await tester.pumpWidget(card(0));
      catalog.complete(0);
      await tester.pumpAndSettle();
      expect(weapons, [5]);
      expect(find.textContaining('Unit #0'), findsOneWidget);
      await tester.pumpWidget(card(1));
      catalog.complete(1);
      await tester.pumpAndSettle();
      expect(weapons, [5, 5]);
      await tester.pumpWidget(card(2));
      catalog.complete(2);
      await tester.pumpAndSettle();
      expect(weapons, [5, 5, 5]);
      await tester.tap(find.byKey(const ValueKey('subunit-weapon-0-air')));
      await tester.pumpAndSettle();
      expect(weapons, [5, 5, 5, 5]);
      expect(units, isEmpty);
      expect(find.textContaining('Unit #2'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(ActionChip, 'Subunit: Terran Marine (#0)'),
      );
      expect(units, [0]);
      await tester.pumpWidget(card(4));
      catalog.complete(3);
      await tester.pumpAndSettle();
      expect(weapons, [5, 5, 5, 5]);
      expect(find.textContaining('No linked weapon'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'late selection results and installation invalidation cannot select stale weapons',
    (tester) async {
      final catalog = _Catalog();
      addTearDown(catalog.events.close);
      final weapons = <int>[];
      Widget card(int unit) => MaterialApp(
        home: Scaffold(
          body: UnitContextCard(
            unit: unit,
            catalog: catalog,
            onWeapon: weapons.add,
            onUnit: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(card(0));
      await tester.pumpWidget(card(4));
      catalog.complete(0);
      catalog.complete(1);
      await tester.pumpAndSettle();
      expect(weapons, isEmpty);
      catalog.weaponReferenceEpoch++;
      catalog.events.add(PlacementCatalogState());
      await tester.pump();
      expect(find.byType(ActionChip), findsNothing);
      catalog.requests[2].completeError(StateError('missing installation'));
      await tester.pumpAndSettle();
      expect(find.text('Retry unit links'), findsOneWidget);
      expect(weapons, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
