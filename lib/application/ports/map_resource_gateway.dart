abstract interface class MapArchiveResourceReader {
  Future<List<int>?> readResource(String archivePath, String resourcePath);
}

abstract interface class MapResourceGateway {
  Future<({String name, List<int> bytes})?> importSound();
  Future<void> exportSound(String name, List<int> bytes);
  Future<void> preview(List<int> bytes);
  Future<void> stopPreview();
  Future<List<int>?> readSound(String archive, String path);
}
