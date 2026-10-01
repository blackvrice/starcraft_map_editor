import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/assets/eud_dat_snapshot_decoder.dart';
import '../fixtures/eud_dat_fixture.dart';

void main() {
  test(
    'decodes complete source provenance, raw unknown values and all tables',
    () {
      final response = syntheticDatResponse();
      (response['columns'] as Map)['image.drawingFunction'][0] = 255;
      final data = decodeEudDat(response, 'test', r'C:\fixture');
      expect(data.hashes, hasLength(7));
      expect(data.snapshot.columns, hasLength(61));
      expect(data.snapshot.value('image.drawingFunction', 0), isNull);
      expect(data.snapshot.raw('image.drawingFunction', 0), 255);
    },
  );
  test(
    'rejects wrong scope, version, hash, duplicate source, incomplete and width overflow',
    () {
      final mutations = <void Function(Map<String, dynamic>)>[
        (r) => r['requestId'] = 'other',
        (r) => r['revision'] = 'other',
        (r) => r['protocolVersion'] = 2,
        (r) => r['installation']['path'] = r'C:\other',
        (r) => r['assets'][0]['sha256'] = 'bad',
        (r) => r['assets'][0] = r['assets'][1],
        (r) => r['columns'].remove('sprite.image'),
        (r) => r['columns']['unit.readySound'] = List.filled(228, 0),
        (r) => r['columns']['weapon.cooldown'][0] = 256,
      ];
      for (final change in mutations) {
        final response = syntheticDatResponse();
        change(response);
        expect(
          () => decodeEudDat(response, 'test', r'C:\fixture'),
          throwsFormatException,
        );
      }
    },
  );
}
