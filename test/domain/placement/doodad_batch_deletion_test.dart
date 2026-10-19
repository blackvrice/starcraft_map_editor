import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import '../../fixtures/doodad_deletion_fixture.dart';

void main() {
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    test(
      'batch $overlay validates adjacent footprints and deletes original indices together',
      () {
        final doc = batchDeletionDocument(overlay: overlay),
            before = const RawChkEncoder().encode(doc);
        final requests = batchDeletionRequests(overlay: overlay);
        expect(
          () => DoodadDeletionPlan.create(
            document: doc,
            recipe: requests.first.recipe,
            recordIndex: 0,
            confirmedOverlayRecordIndex:
                requests.first.confirmedOverlayRecordIndex,
          ),
          throwsStateError,
        );
        final plan = DoodadDeletionPlan.createBatch(
          document: doc,
          requests: requests.reversed,
        );
        expect(plan.document, same(doc));
        expect(plan.doodadCount, 2);
        expect(plan.overlayCount, overlay == null ? 0 : 2);
        var after = doc;
        for (final entry in plan.replacements.entries) {
          after = after.replaceSection(entry.key, entry.value);
        }
        final dd = doc.sections.singleWhere((s) => s.name == 'DD2 ').payload;
        expect(
          after.sections.singleWhere((s) => s.name == 'DD2 ').payload,
          dd.sublist(8, 16),
        );
        final sprites = doc.sections
            .singleWhere((s) => s.name == 'THG2')
            .payload;
        expect(
          after.sections.singleWhere((s) => s.name == 'THG2').payload,
          overlay == null
              ? sprites
              : [...sprites.take(10), ...sprites.skip(20).take(10)],
        );
        expect(
          const ChkTerrainViewDecoder()
              .decode(after)
              .tileMaps
              .single
              .rawTileValues,
          everyElement(1),
        );
        expect(const RawChkEncoder().encode(doc), before);
        expect(() => plan.replacements.clear(), throwsUnsupportedError);
        for (var i = 0; i < doc.sections.length; i++) {
          if (!plan.replacements.containsKey(i)) {
            expect(after.sections[i], same(doc.sections[i]));
          }
        }
      },
    );
  }
  test(
    'one invalid member rejects every change and never shifts later record IDs',
    () {
      final base = batchDeletionDocument(
        overlay: DoodadOverlaySemantic.spriteUnit,
      );
      RawChkDocument patch(String name, void Function(Uint8List) change) {
        final at = base.sections.indexWhere((s) => s.name == name),
            bytes = base.sections[at].payload;
        change(bytes);
        return base.replaceSection(at, base.sections[at].withPayload(bytes));
      }

      for (final doc in [
        batchDeletionDocument(
          overlay: DoodadOverlaySemantic.spriteUnit,
          overlap: true,
        ),
        patch('DD2 ', (b) => b[23] = 255),
        patch('DD2 ', (b) {
          b[10] = 112;
          b[11] = 0;
          b[12] = 48;
          b[13] = 0;
        }),
        patch('MTXM', (b) {
          b[68] = 1;
          b[69] = 0;
        }),
        patch('THG2', (b) => b[38] = 1),
      ]) {
        final before = const RawChkEncoder().encode(doc);
        expect(
          () => DoodadDeletionPlan.createBatch(
            document: doc,
            requests: batchDeletionRequests(
              overlay: DoodadOverlaySemantic.spriteUnit,
            ),
          ),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(doc), before);
      }
    },
  );
  test(
    'duplicate DD2/overlay ownership and missing confirmations fail closed',
    () {
      final doc = batchDeletionDocument(
            overlay: DoodadOverlaySemantic.spriteUnit,
          ),
          requests = batchDeletionRequests(
            overlay: DoodadOverlaySemantic.spriteUnit,
          );
      for (final list in [
        [requests.first, requests.first],
        [
          requests.first,
          DoodadDeletionRequest(
            recipe: requests.last.recipe,
            recordIndex: 2,
            confirmedOverlayRecordIndex: 1,
          ),
        ],
        [
          requests.first,
          DoodadDeletionRequest(recipe: requests.last.recipe, recordIndex: 2),
        ],
        [
          requests.first,
          DoodadDeletionRequest(
            recipe: requests.last.recipe,
            recordIndex: 999,
            confirmedOverlayRecordIndex: 3,
          ),
        ],
      ]) {
        expect(
          () => DoodadDeletionPlan.createBatch(document: doc, requests: list),
          throwsStateError,
        );
      }
    },
  );
  test(
    '32-item boundary succeeds; empty, oversized and unbounded iterables are rejected',
    () {
      final doc = batchDeletionDocument(
            count: 32,
            overlay: DoodadOverlaySemantic.spriteUnit,
          ),
          requests = batchDeletionRequests(
            count: 32,
            overlay: DoodadOverlaySemantic.spriteUnit,
          );
      expect(
        DoodadDeletionPlan.createBatch(
          document: doc,
          requests: requests,
        ).doodadCount,
        32,
      );
      expect(
        () => DoodadDeletionPlan.createBatch(document: doc, requests: const []),
        throwsStateError,
      );
      var yielded = 0;
      Iterable<DoodadDeletionRequest> endless() sync* {
        while (true) {
          yielded++;
          yield requests.first;
        }
      }

      expect(
        () =>
            DoodadDeletionPlan.createBatch(document: doc, requests: endless()),
        throwsStateError,
      );
      expect(yielded, 33);
      final plan = DoodadDeletionPlan.createBatch(
        document: doc,
        requests: requests,
      );
      var after = doc;
      for (final entry in plan.replacements.entries) {
        after = after.replaceSection(entry.key, entry.value);
      }
      expect(
        const ChkObjectViewDecoder()
            .decode(after)
            .doodadSections
            .single
            .doodads,
        hasLength(1),
      );
      expect(
        const ChkObjectViewDecoder()
            .decode(after)
            .spriteSections
            .single
            .sprites,
        hasLength(2),
      );
      expect(
        const ChkTerrainViewDecoder()
            .decode(after)
            .tileMaps
            .single
            .rawTileValues,
        everyElement(1),
      );
    },
  );
}
