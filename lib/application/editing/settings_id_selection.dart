/// Parses an explicit selection, never interpreting a search as a write scope.
Set<int> parseSettingsIds(String input, int count) {
  if (count < 1 || input.trim().isEmpty || input.length > 512) {
    throw const FormatException('Enter IDs such as 0, 2-5.');
  }
  final ids = <int>{};
  for (final part in input.split(',')) {
    final match = RegExp(r'^\s*(\d+)\s*(?:-\s*(\d+)\s*)?$').firstMatch(part);
    if (match == null) {
      throw const FormatException(
        'Use comma-separated IDs or ascending ranges.',
      );
    }
    final first = int.parse(match[1]!);
    final last = int.parse(match[2] ?? match[1]!);
    if (first > last || first < 0 || last >= count) {
      throw FormatException(
        'IDs must be between 0 and ${count - 1}, in ascending ranges.',
      );
    }
    for (var id = first; id <= last; id++) {
      ids.add(id);
    }
  }
  return Set.unmodifiable(ids);
}

/// Snapshots only the source draft fields; callers merge after validation.
Map<K, V> copySettingsDraft<K, V>(
  Map<K, V> draft,
  bool Function(K) isSource,
  K Function(K, int) targetKey,
  Set<int> ids,
) {
  final source = draft.entries.where((e) => isSource(e.key)).toList();
  return {
    for (final id in ids)
      for (final e in source) targetKey(e.key, id): e.value,
  };
}
