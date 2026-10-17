/// A workspace-wide output/input reservation, held through asynchronous I/O.
final class DocumentPathLease {
  DocumentPathLease({required this._validate, required this._release});
  final Future<void> Function() _validate;
  final void Function() _release;
  bool _released = false;
  Future<void> validate() {
    if (_released) throw StateError('WORKSPACE_PATH_LEASE_RELEASED');
    return _validate();
  }

  void release() {
    if (!_released) {
      _released = true;
      _release();
    }
  }
}

typedef DocumentPathReserver = Future<DocumentPathLease> Function(String path);
