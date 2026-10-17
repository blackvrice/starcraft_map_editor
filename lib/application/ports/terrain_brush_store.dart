abstract interface class TerrainBrushStore {
  Future<List<String>> readAll();
  Future<void> add(String name, String content);
  Future<void> remove(String name);
}
