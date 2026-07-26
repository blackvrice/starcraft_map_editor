abstract interface class MapFilePicker {
  Future<String?> pickMapPath();

  Future<String?> pickSaveMapPath({required String suggestedName});
}
