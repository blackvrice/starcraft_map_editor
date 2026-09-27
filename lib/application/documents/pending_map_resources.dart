import 'dart:collection';

/// Immutable snapshot shared by a document and its undo commands.
final class PendingMapResources extends MapView<String, List<int>?> {
  factory PendingMapResources(Map<String, List<int>?> values) =>
      values is PendingMapResources ? values : PendingMapResources._(values);

  PendingMapResources._(Map<String, List<int>?> values)
    : super(
        Map.unmodifiable(
          values.map(
            (key, bytes) => MapEntry(
              key,
              bytes == null
                  ? null
                  : bytes is _ResourceBytes
                  ? bytes
                  : _ResourceBytes(bytes),
            ),
          ),
        ),
      );
}

final class _ResourceBytes extends UnmodifiableListView<int> {
  _ResourceBytes(List<int> bytes) : super(List<int>.unmodifiable(bytes));
}
