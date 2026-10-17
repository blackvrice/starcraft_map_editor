import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_document_transfer.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import '../../fixtures/basic_editing_fixture.dart';
import '../../fixtures/mixed_clipboard_fixture.dart';
import '../../fixtures/solid_isom_fixture.dart';

void main() {
  final catalog = const TransitionIsomCatalogBuilder().build(solidSnapshot());
  RawChkDocument base(MixedClipboardProfile profile) =>
      profile == MixedClipboardProfile.raw
      ? basicDocument()
      : const IsomTerrainFill()
            .preview(basicDocument(), catalog.catalog, solidValue: 16, seed: 0)
            .result;
  for (final profile in MixedClipboardProfile.values) {
    test(
      '${profile.name} transfers complete Doodads, exact overlays and linked units to a different map with independent string/location IDs',
      () {
        var source = ChkResourceEditor.addRaw(
          mixedDocument(base: base(profile)),
          [4, 0xff],
        );
        final name = ChkResourceEditor.table(source).declaredStringCount;
        final location = basicData(source, 'MRGN')
          ..setUint16(16, name, Endian.little);
        source = mixedPut(source, 'MRGN', location.buffer.asUint8List());
        var target = ChkResourceEditor.addRaw(base(profile), [65]);
        final used = ChkTrigger.create().withSlot(
          true,
          0,
          ChkTrigger.makeSlot(true, TriggerOpcodes.find(true, 10)!, {
            'Location ID': 1,
          }, target),
        );
        target = mixedPut(target, 'TRIG', used.bytes);
        final sourceBytes = const RawChkEncoder().encode(source),
            targetBytes = const RawChkEncoder().encode(target);
        final clip = ChkMixedClipboard.capture(
          source,
          region: ClipboardRegion(0, 0, 7, 5),
          profile: profile,
          kinds: {'UNIT', 'THG2', 'DD2 ', 'MRGN'},
          overlays: {0: 2, 1: 1},
          data: MixedClipboardData(
            recipes: [mixedRecipe],
            catalog: catalog.catalog,
            brush: catalog.brush,
          ),
        );
        final plan = ChkMixedDocumentTransferPlan.preview(
          clip,
          target,
          x: 16,
          y: 16,
        );
        expect(plan.references!.locations[1], 2);
        expect(plan.units, {11: 1, 12: 2});
        final result = plan.result;
        expect(basicData(result, 'DD2 ').lengthInBytes, 16);
        expect(basicData(result, 'DD2 ').getUint16(2, Endian.little), 608);
        expect(basicData(result, 'DD2 ').getUint8(15), 1);
        expect(basicData(result, 'THG2').lengthInBytes, 30);
        expect(basicData(result, 'THG2').getUint16(18, Endian.little), 0x8000);
        expect(basicData(result, 'UNIT').getUint32(32, Endian.little), 2);
        expect(basicData(result, 'UNIT').getUint32(68, Endian.little), 1);
        expect(
          basicData(result, 'MRGN').getUint32(20, Endian.little),
          160 + 512,
        );
        expect(
          basicData(result, 'MRGN').getUint32(28, Endian.little),
          96 + 512,
        );
        expect(basicData(result, 'MRGN').getUint16(38, Endian.little), 19);
        expect(basicData(result, 'MRGN').getUint32(0, Endian.little), 0);
        expect(
          ChkResourceEditor.table(
            result,
          ).entryForId(plan.references!.strings[name]!)!.rawBytes,
          [4, 0xff],
        );
        expect(ChkResourceEditor.table(result).entryForId(name)!.rawBytes, [
          65,
        ]);
        expect(ChkTriggers.read(result).records.single.bytes, used.bytes);
        expect(const RawChkEncoder().encode(source), sourceBytes);
        expect(const RawChkEncoder().encode(target), targetBytes);
        expect(
          () =>
              ChkMixedDocumentTransferPlan.preview(clip, result, x: 16, y: 16),
          throwsStateError,
        );
        expect(
          () =>
              ChkMixedDocumentTransferPlan.preview(clip, target, x: 31, y: 31),
          throwsRangeError,
        );
        if (profile == MixedClipboardProfile.isom) {
          expect(
            () => ChkMixedDocumentTransferPlan.preview(
              clip,
              target,
              x: 14,
              y: 16,
            ),
            throwsStateError,
          );
        }
      },
    );
  }
  test('mixed raw transfer does not equate reused numeric string IDs', () {
    var source = mixedDocument();
    final loc = basicData(source, 'MRGN')..setUint16(16, 1, Endian.little);
    source = mixedPut(source, 'MRGN', loc.buffer.asUint8List());
    final clip = ChkMixedClipboard.capture(
      source,
      region: ClipboardRegion(0, 0, 7, 5),
      profile: MixedClipboardProfile.raw,
      kinds: {'UNIT', 'THG2', 'DD2 ', 'MRGN'},
      overlays: {0: 2, 1: 1},
      data: MixedClipboardData(recipes: [mixedRecipe]),
    );
    final target = ChkResourceEditor.edit(basicDocument(), 1, 'Different map');
    final plan = ChkMixedDocumentTransferPlan.preview(
      clip,
      target,
      x: 16,
      y: 16,
    );
    expect(plan.references!.strings[1], isNot(1));
    expect(
      ChkResourceEditor.table(plan.result).entryForId(1)!.rawBytes,
      'Different map'.codeUnits,
    );
  });
}
