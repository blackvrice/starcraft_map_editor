abstract interface class EudProjectPicker {
  Future<String?> openProject();
  Future<String?> saveProjectAs();
}
