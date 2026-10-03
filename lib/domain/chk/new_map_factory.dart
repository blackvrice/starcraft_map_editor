import 'dart:convert';
import 'dart:typed_data';

import 'default_validation_code.dart';
import '../terrain/isom_terrain_conversion.dart';
import '../terrain/isom_terrain_fill.dart';
import 'raw_chk_document.dart';
import 'raw_chk_section.dart';
import 'typed/chk_metadata_views.dart';

/// UMS creation policy. Terrain uses a verified local catalog; explicit raw
/// tile mode remains available without inventing ISOM metadata.
final class NewMapOptions {
  NewMapOptions({
    this.width = 128,
    this.height = 128,
    this.tileset = ChkTileset.badlands,
    required this.rawTileValue,
    this.humanPlayers = 1,
    this.title = 'Untitled Scenario',
    this.description = '',
    this.terrainCatalog,
    this.solidTerrainValue,
    this.terrainSeed = 0,
  }) {
    for (final dimension in [width, height]) {
      if (dimension < 32 || dimension > 256 || dimension % 32 != 0) {
        throw ArgumentError(
          'Map dimensions must be multiples of 32 from 32 to 256.',
        );
      }
    }
    RangeError.checkValueInInterval(rawTileValue, 0, 65535, 'rawTileValue');
    RangeError.checkValueInInterval(humanPlayers, 1, 8, 'humanPlayers');
    RangeError.checkValueInInterval(terrainSeed, 0, 0xffffffff, 'terrainSeed');
    if ((terrainCatalog == null) != (solidTerrainValue == null) ||
        (terrainCatalog != null &&
            terrainCatalog!.tileset != tileset.rawValue)) {
      throw ArgumentError(
        'Terrain needs a verified matching catalog and solid shape.',
      );
    }
    if (title.trim().isEmpty ||
        title.contains('\u0000') ||
        description.contains('\u0000')) {
      throw ArgumentError('A map needs a nonblank title and NUL-free text.');
    }
  }

  final int width, height, rawTileValue, humanPlayers;
  final ChkTileset tileset;
  final String title, description;
  final IsomTerrainCatalog? terrainCatalog;
  final int? solidTerrainValue;
  final int terrainSeed;
}

/// Deterministic, template-free CHK construction. Does not touch an existing
/// document or archive and does not synthesize unverified ISOM data.
class NewMapFactory {
  const NewMapFactory();

  RawChkDocument create(NewMapOptions options) {
    final sections = <RawChkSection>[];
    var offset = 0;
    void add(String name, List<int> bytes) {
      sections.add(
        RawChkSection(
          nameBytes: ascii.encode(name),
          declaredLength: bytes.length,
          payload: bytes,
          sourceOffset: offset,
          isDirty: true,
        ),
      );
      offset += 8 + bytes.length;
    }

    // IDs are stable and independent of whether the description is empty.
    final strings = _strings([
      options.title,
      options.description,
      'Anywhere',
      'Force 1',
      'Force 2',
      'Force 3',
      'Force 4',
    ]);
    final owners = List<int>.generate(
      12,
      (i) => i < options.humanPlayers ? 6 : (i == 11 ? 7 : 0),
    );
    final races = List<int>.generate(
      12,
      (i) => i < options.humanPlayers ? 1 : (i == 11 ? 4 : 7),
    );
    final tiles = ByteData(options.width * options.height * 2);
    for (var i = 0; i < tiles.lengthInBytes; i += 2) {
      tiles.setUint16(i, options.rawTileValue, Endian.little);
    }
    final locations = ByteData(255 * 20);
    const anywhere = 63 * 20; // CHK location ID 64, zero-based record 63.
    locations
      ..setUint32(anywhere + 8, options.width * 32, Endian.little)
      ..setUint32(anywhere + 12, options.height * 32, Endian.little)
      ..setUint16(anywhere + 16, 3, Endian.little);
    final forces = ByteData(20);
    for (var i = 0; i < 4; i++) {
      forces.setUint16(8 + i * 2, 4 + i, Endian.little);
    }

    add('TYPE', ascii.encode('RAWB'));
    add('VER ', _u16([205]));
    add('IVE2', _u16([11]));
    add('VCOD', validationCode());
    add('IOWN', owners);
    add('OWNR', owners);
    add('ERA ', _u16([options.tileset.rawValue]));
    add('DIM ', _u16([options.width, options.height]));
    add('SIDE', races);
    add('MTXM', tiles.buffer.asUint8List());
    add('PUNI', Uint8List(5700)..fillRange(0, 5700, 1));
    add('UNIT', _starts(options));
    add('TILE', tiles.buffer.asUint8List());
    add('DD2 ', const []);
    add('THG2', const []);
    add('MASK', List<int>.filled(options.width * options.height, 255));
    add('STR ', strings);
    add('UPRP', Uint8List(64 * 20));
    add('UPUS', Uint8List(64));
    add('MRGN', locations.buffer.asUint8List());
    // UMS authors explicitly add victory/defeat/resources rules as needed.
    add('TRIG', const []);
    add('MBRF', const []);
    add('SPRP', _u16([1, options.description.isEmpty ? 0 : 2]));
    add('FORC', forces.buffer.asUint8List());
    add('WAV ', Uint8List(512 * 4));
    add('SWNM', Uint8List(256 * 4));
    add('COLR', List<int>.generate(8, (i) => i));
    final upgrades = Uint8List(2318)
      ..setRange(24 * 61, 25 * 61, _upgradeMaximums)
      ..fillRange(26 * 61, 38 * 61, 1);
    add('PUPx', upgrades);
    final techs = Uint8List(1672)
      ..fillRange(24 * 44, 25 * 44, 1)
      ..fillRange(26 * 44, 38 * 44, 1);
    for (final tech in [4, 6, 12, 14, 18, 23, 28, 29, 33, 34]) {
      techs[25 * 44 + tech] = 1;
    }
    add('PTEx', techs);
    add('UNIx', Uint8List(4168)..fillRange(0, 228, 1));
    add('UPGx', Uint8List(794)..fillRange(0, 61, 1));
    add('TECx', Uint8List(396)..fillRange(0, 44, 1));
    final document = RawChkDocument(sections: sections, sourceLength: offset);
    // Generate the complete terrain before publishing the new session: a
    // failed conversion must never leave a partially created map open.
    return options.terrainCatalog == null
        ? document
        : const IsomTerrainFill()
              .preview(
                document,
                options.terrainCatalog!,
                solidValue: options.solidTerrainValue!,
                seed: options.terrainSeed,
              )
              .result;
  }

  // Standard expansion upgrade level defaults, cross-checked against the
  // pinned Chkdraft PUPx layout in docs/NEW_MAP.md. Not DAT asset bytes.
  static const _upgradeMaximums = [
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    1,
    1,
    0,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    0,
    0,
    1,
    0,
    1,
    0,
    1,
    1,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
  ];

  Uint8List _starts(NewMapOptions options) {
    final data = ByteData(options.humanPlayers * 36);
    const positions = [
      (1, 1),
      (3, 3),
      (3, 1),
      (1, 3),
      (2, 1),
      (2, 3),
      (1, 2),
      (3, 2),
    ];
    for (var i = 0; i < options.humanPlayers; i++) {
      final (x, y) = options.humanPlayers == 1 ? (2, 2) : positions[i];
      final start = i * 36;
      data
        ..setUint32(start, i + 1, Endian.little)
        ..setUint16(start + 4, options.width * 8 * x, Endian.little)
        ..setUint16(start + 6, options.height * 8 * y, Endian.little)
        ..setUint16(start + 8, 214, Endian.little)
        ..setUint16(start + 14, 1, Endian.little)
        ..setUint8(start + 16, i)
        ..setUint8(start + 17, 100)
        ..setUint8(start + 18, 100)
        ..setUint8(start + 19, 100);
    }
    return data.buffer.asUint8List();
  }

  Uint8List _strings(List<String> strings) {
    final encoded = strings.map(utf8.encode).toList();
    final size =
        2 +
        strings.length * 2 +
        encoded.fold<int>(0, (n, s) => n + s.length + 1);
    if (size > 65535) {
      throw ArgumentError(
        'Initial map text exceeds the legacy STR byte limit.',
      );
    }
    final data = ByteData(size)..setUint16(0, strings.length, Endian.little);
    final bytes = data.buffer.asUint8List();
    var offset = 2 + strings.length * 2;
    for (var i = 0; i < encoded.length; i++) {
      data.setUint16(2 + i * 2, offset, Endian.little);
      bytes.setRange(offset, offset + encoded[i].length, encoded[i]);
      offset += encoded[i].length + 1;
    }
    return bytes;
  }

  Uint8List _u16(List<int> values) {
    final data = ByteData(values.length * 2);
    for (var i = 0; i < values.length; i++) {
      data.setUint16(i * 2, values[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
