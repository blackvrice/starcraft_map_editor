import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import '../../fixtures/doodad_deletion_fixture.dart';

void main() {
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    for (final state in [0, 1]) {
      test(
        'deletes verified state=$state overlay=$overlay without changing surviving bytes',
        () {
          final doc = deletionDocument(state: state, overlay: overlay),
              before = const RawChkEncoder().encode(doc);
          final plan = DoodadDeletionPlan.create(
            document: doc,
            recipe: deletionRecipe(overlay: overlay),
            recordIndex: 0,
            confirmedOverlayRecordIndex: overlay == null ? null : 1,
          );
          var after = doc;
          for (final entry in plan.replacements.entries) {
            after = after.replaceSection(entry.key, entry.value);
          }
          final dd = doc.sections.singleWhere((s) => s.name == 'DD2 ').payload;
          expect(
            after.sections.singleWhere((s) => s.name == 'DD2 ').payload,
            dd.sublist(8),
          );
          final thg = doc.sections.singleWhere((s) => s.name == 'THG2').payload;
          expect(
            after.sections.singleWhere((s) => s.name == 'THG2').payload,
            overlay == null ? thg : [...thg.take(10), ...thg.skip(20)],
          );
          for (var i = 0; i < doc.sections.length; i++) {
            if (!plan.replacements.containsKey(i)) {
              expect(after.sections[i], same(doc.sections[i]));
            }
          }
          final terrain = const ChkTerrainViewDecoder()
              .decode(after)
              .tileMaps
              .single;
          expect(terrain.rawTileValues, everyElement(1));
          expect(const RawChkEncoder().encode(doc), before);
          expect(
            const RawChkParser()
                .parse(const RawChkEncoder().encode(after))
                .isSuccess,
            isTrue,
          );
        },
      );
    }
  }
  for (final state in [2, 255]) {
    test('unknown DD2 state $state is rejected without mutation', () {
      final doc = deletionDocument(state: state),
          before = const RawChkEncoder().encode(doc);
      expect(
        () => DoodadDeletionPlan.create(
          document: doc,
          recipe: deletionRecipe(),
          recordIndex: 0,
        ),
        throwsStateError,
      );
      expect(const RawChkEncoder().encode(doc), before);
    });
  }
  for (final (semantic, flags) in [
    (DoodadOverlaySemantic.spriteUnit, 0),
    (DoodadOverlaySemantic.spriteUnit, 0x8001),
    (DoodadOverlaySemantic.pureSprite, 0x9000),
  ]) {
    test(
      'disabled $semantic rejects inconsistent/unknown overlay flags $flags',
      () {
        final doc = deletionDocument(overlay: semantic, flags: flags),
            before = const RawChkEncoder().encode(doc);
        expect(
          () => DoodadDeletionPlan.create(
            document: doc,
            recipe: deletionRecipe(overlay: semantic),
            recordIndex: 0,
            confirmedOverlayRecordIndex: 1,
          ),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(doc), before);
      },
    );
  }
  test('disabled overlay still needs explicit ownership and valid TILE', () {
    final doc = deletionDocument(overlay: DoodadOverlaySemantic.spriteUnit),
        recipe = deletionRecipe(overlay: DoodadOverlaySemantic.spriteUnit);
    for (final overlay in [null, 0, 99]) {
      expect(
        () => DoodadDeletionPlan.create(
          document: doc,
          recipe: recipe,
          recordIndex: 0,
          confirmedOverlayRecordIndex: overlay,
        ),
        throwsStateError,
      );
    }
    final tile = doc.sections.indexWhere((s) => s.name == 'TILE');
    for (final invalid in [
      doc.appendSection(doc.sections[tile]),
      doc.replaceSection(tile, doc.sections[tile].withPayload([0])),
      doc.replaceSection(
        tile,
        doc.sections[tile].withPayload(
          doc.sections.singleWhere((s) => s.name == 'MTXM').payload,
        ),
      ),
    ]) {
      expect(
        () => DoodadDeletionPlan.create(
          document: invalid,
          recipe: recipe,
          recordIndex: 0,
          confirmedOverlayRecordIndex: 1,
        ),
        throwsStateError,
      );
    }
  });
  test(
    'disabled deletion retains every geometry, neighbor, section and overlay guard',
    () {
      final doc = deletionDocument(overlay: DoodadOverlaySemantic.spriteUnit),
          recipe = deletionRecipe(overlay: DoodadOverlaySemantic.spriteUnit);
      RawChkDocument patch(String name, void Function(List<int>) change) {
        final at = doc.sections.indexWhere((s) => s.name == name),
            bytes = doc.sections[at].payload;
        change(bytes);
        return doc.replaceSection(at, doc.sections[at].withPayload(bytes));
      }

      final invalid = [
        patch('DD2 ', (b) => b[2] = 49),
        patch('DD2 ', (b) {
          b[2] = 255;
          b[3] = 255;
        }),
        patch('DD2 ', (b) {
          b[10] = 48;
          b[11] = 0;
          b[12] = 48;
          b[13] = 0;
        }),
        patch('MTXM', (b) {
          b[66] = 0;
          b[67] = 0;
        }),
        patch('THG2', (b) => b[10] = 99),
        patch('THG2', (b) => b[16] = 4),
        patch('THG2', (b) => b[17] = 1),
        patch('THG2', (b) => b[12] = 49),
        for (final name in ['DIM ', 'ERA ', 'MTXM', 'DD2 ', 'THG2'])
          doc.appendSection(doc.sections.singleWhere((s) => s.name == name)),
      ];
      for (final source in invalid) {
        final before = const RawChkEncoder().encode(source);
        expect(
          () => DoodadDeletionPlan.create(
            document: source,
            recipe: recipe,
            recordIndex: 0,
            confirmedOverlayRecordIndex: 1,
          ),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(source), before);
      }
    },
  );
}
