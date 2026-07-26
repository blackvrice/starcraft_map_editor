abstract interface class MapFilePicker {
  Future<String?> pickMapPath();

  /// Returns an existing path only after the user explicitly confirms that
  /// the destination may be replaced.
  Future<String?> pickSaveMapPath({required String suggestedName});
}
