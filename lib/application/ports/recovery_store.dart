final class RecoveryEntry {
  const RecoveryEntry({required this.id, required this.content});
  final String id;
  final String content;
}

abstract interface class RecoveryStore {
  Future<List<RecoveryEntry>> list();
  Future<void> write(String id, String content);
  Future<void> remove(String id);
}
