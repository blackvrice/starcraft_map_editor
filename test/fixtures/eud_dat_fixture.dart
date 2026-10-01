import 'package:starcraft_map_editor/domain/eud/eud_dat_layout.dart';
import 'package:starcraft_map_editor/domain/eud/eud_dat_snapshot.dart';
import 'package:starcraft_map_editor/application/ports/eud_dat_gateway.dart';

Map<String, List<int>> syntheticDatColumns() => {
  for (final e in EudDatLayout.counts.entries)
    e.key: List.filled(e.value, switch (e.key) {
      'unit.subunit1' || 'unit.subunit2' => 228,
      'unit.groundWeapon' || 'unit.airWeapon' => 130,
      'unit.flingy' || 'weapon.flingy' => 208,
      'flingy.sprite' => 516,
      'sprite.image' || 'unit.construction_animation' => 998,
      'weapon.cooldown' => 15,
      _ => 0,
    }),
};
EudDatSource syntheticDatSource([Map<String, List<int>>? columns]) =>
    EudDatSource(
      snapshot: EudDatSnapshot(columns ?? syntheticDatColumns()),
      helperVersion: '0.11.0',
      product: 'synthetic',
      build: 1,
      hashes: {for (final key in EudDatLayout.assets.keys) key: 'a' * 64},
    );
Map<String, dynamic> syntheticDatResponse() => {
  'protocolVersion': 3,
  'requestId': 'test',
  'operation': 'readEudDat',
  'status': 'success',
  'snapshotVersion': 1,
  'revision': EudDatLayout.revision,
  'helperVersion': '0.11.0',
  'cascLibRevision': '4971d363e665551ac4142f541e5f2d71f1cda653',
  'installation': {
    'path': r'C:\fixture',
    'storageProduct': 'synthetic',
    'storageBuildNumber': 1,
  },
  'assets': [
    for (final e in EudDatLayout.assets.entries)
      {'path': e.key, 'bytes': e.value, 'sha256': 'a' * 64},
  ],
  'columns': syntheticDatColumns(),
};
