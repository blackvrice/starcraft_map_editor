import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/map_resize.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';

RawChkDocument fixture() {
  var doc = const NewMapFactory().create(
    NewMapOptions(width: 64, height: 64, rawTileValue: 77),
  );
  final tiles = ByteData(64 * 64 * 2);
  for (var i = 0; i < 4096; i++) {
    tiles.setUint16(i * 2, i, Endian.little);
  }
  doc = change(doc, 'MTXM', tiles.buffer.asUint8List());
  doc = change(doc, 'TILE', tiles.buffer.asUint8List());
  doc = change(doc, 'MASK', List.generate(4096, (i) => i % 256));
  // Keep one start location well inside a centered crop.
  final units = section(doc, 'UNIT').payload;
  ByteData.sublistView(units)
    ..setUint16(4, 1024, Endian.little)
    ..setUint16(6, 1024, Endian.little);
  return change(doc, 'UNIT', units);
}

RawChkSection section(RawChkDocument doc, String name) =>
    doc.sections.singleWhere((s) => s.name == name);
RawChkDocument change(RawChkDocument doc, String name, List<int> bytes) {
  final index = doc.sections.indexWhere((s) => s.name == name);
  return doc.replaceSection(index, doc.sections[index].withPayload(bytes));
}

RawChkSection extra(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);

void main() {
  test(
    'all nine anchors translate independent rectangular grids and preserve unknown sections',
    () {
      for (final anchor in MapResizeAnchor.values) {
        final source = fixture().appendSection(extra('????', [255, 3, 7]));
        final before = const RawChkEncoder().encode(source);
        final p = const MapResizeEditor().preview(
          source,
          MapResizeOptions(
            width: 96,
            height: 128,
            anchor: anchor,
            fillX: 2,
            fillY: 3,
          ),
        );
        expect(p.canApply, isTrue);
        expect(p.dx, anchor.x * 16);
        expect(p.dy, anchor.y * 32);
        expect(p.addedTiles, 96 * 128 - 4096);
        expect(p.croppedTiles, 0);
        final result = p.apply(acceptCropping: false);
        expect(section(result, '????'), same(section(source, '????')));
        expect(section(result, 'TRIG'), same(section(source, 'TRIG')));
        for (final name in ['MTXM', 'TILE']) {
          final b = ByteData.sublistView(section(result, name).payload);
          expect(
            b.getUint16(((3 + p.dy) * 96 + 2 + p.dx) * 2, Endian.little),
            194,
          );
          final outside = p.dx > 0 || p.dy > 0 ? 0 : 96 * 128 - 1;
          expect(b.getUint16(outside * 2, Endian.little), 194);
        }
        final mask = section(result, 'MASK').payload;
        expect(mask[(3 + p.dy) * 96 + 2 + p.dx], 194);
        expect(mask[p.dx > 0 || p.dy > 0 ? 0 : mask.length - 1], 255);
        final unit = ByteData.sublistView(section(result, 'UNIT').payload);
        expect(unit.getUint16(4, Endian.little), 1024 + p.dx * 32);
        expect(unit.getUint16(6, Endian.little), 1024 + p.dy * 32);
        final location = ByteData.sublistView(section(result, 'MRGN').payload);
        expect(location.getUint32(63 * 20 + 8, Endian.little), 96 * 32);
        expect(location.getUint32(63 * 20 + 12, Endian.little), 128 * 32);
        final encoded = const RawChkEncoder().encode(result);
        expect(
          const RawChkEncoder().encode(
            const RawChkParser().parse(encoded).document!,
          ),
          encoded,
        );
        expect(const RawChkEncoder().encode(source), before);
      }
    },
  );
  test(
    'crop requires confirmation, clips reversed/fully outside locations without renumbering',
    () {
      var source = fixture();
      final locations = section(source, 'MRGN').payload;
      ByteData.sublistView(locations)
        ..setUint32(0, 1900, Endian.little)
        ..setUint32(4, 1900, Endian.little)
        ..setUint32(8, 1800, Endian.little)
        ..setUint32(12, 1800, Endian.little)
        ..setUint16(16, 1, Endian.little)
        ..setUint16(18, 0x8123, Endian.little);
      source = change(source, 'MRGN', locations);
      final p = const MapResizeEditor().preview(
        source,
        MapResizeOptions(width: 32, height: 32, anchor: MapResizeAnchor.center),
      );
      expect(p.canApply, isTrue);
      expect(p.croppedTiles, 3072);
      expect(p.clippedLocations, 1);
      expect(() => p.apply(acceptCropping: false), throwsStateError);
      final result = p.apply(acceptCropping: true);
      final b = ByteData.sublistView(section(result, 'MRGN').payload);
      expect(
        [for (var i = 0; i < 4; i++) b.getUint32(i * 4, Endian.little)],
        [1024, 1024, 1024, 1024],
      );
      expect(b.getUint16(16, Endian.little), 1);
      expect(b.getUint16(18, Endian.little), 0x8123);
      expect(
        section(result, 'MRGN').payload.sublist(20, 40),
        List.filled(20, 0),
      );
      final tile = ByteData.sublistView(section(result, 'MTXM').payload);
      expect(tile.getUint16(0, Endian.little), 16 * 64 + 16);
    },
  );
  test(
    'outside units/sprites block application instead of breaking relationships or record IDs',
    () {
      var source = fixture();
      final sprite = ByteData(10)
        ..setUint16(2, 1800, Endian.little)
        ..setUint16(4, 1800, Endian.little);
      source = change(source, 'THG2', sprite.buffer.asUint8List());
      final p = const MapResizeEditor().preview(
        source,
        MapResizeOptions(width: 32, height: 32),
      );
      expect(p.outsideUnits, 1);
      expect(p.outsideSprites, 1);
      expect(p.canApply, isFalse);
      expect(() => p.apply(acceptCropping: true), throwsStateError);
    },
  );
  test(
    'ISOM, doodads, duplicates and malformed grids are never silently repaired',
    () {
      final source = fixture();
      final options = MapResizeOptions(width: 96, height: 96);
      for (final doc in [
        source.appendSection(extra('ISOM', [])),
        change(source, 'DD2 ', List.filled(8, 0)),
      ]) {
        expect(const MapResizeEditor().preview(doc, options).canApply, isFalse);
      }
      for (final doc in [
        source.appendSection(section(source, 'MTXM')),
        change(source, 'MASK', [0]),
        change(source, 'THG2', [0]),
      ]) {
        expect(
          () => const MapResizeEditor().preview(doc, options),
          throwsStateError,
        );
      }
      expect(
        () => MapResizeOptions(width: 33, height: 64),
        throwsArgumentError,
      );
      expect(
        () => const MapResizeEditor().preview(
          source,
          MapResizeOptions(width: 96, height: 96, fillX: 64),
        ),
        throwsRangeError,
      );
    },
  );
}
