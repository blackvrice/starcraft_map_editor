import 'package:starcraft_map_editor/application/ports/terrain_brush_store.dart';
import 'package:starcraft_map_editor/domain/terrain/user_terrain_brush.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'basic_editing_fixture.dart';

UserTerrainBrush rawUserBrush({String name = 'Cliff'}) =>
    UserTerrainBrush.capture(
      basicDocument(),
      name: name,
      region: ClipboardRegion(0, 0, 1, 1),
      profile: TerrainBrushProfile.raw,
    );

class MemoryTerrainBrushStore implements TerrainBrushStore {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<List<String>> readAll() async => values.values.toList();
  @override
  Future<void> add(String name, String content) async {
    if (failWrites) throw StateError('write failed');
    if (values.containsKey(name)) throw StateError('exists');
    values[name] = content;
  }

  @override
  Future<void> remove(String name) async => values.remove(name);
}
