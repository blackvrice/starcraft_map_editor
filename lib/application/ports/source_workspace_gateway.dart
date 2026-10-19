final class SourceWorkspaceFile {
  const SourceWorkspaceFile({
    required this.relativePath,
    required this.path,
    required this.text,
    required this.revision,
    this.backupPath,
  });
  final String relativePath, path, text, revision;
  final String? backupPath;
}

final class SourceWorkspaceScan {
  SourceWorkspaceScan(this.root, Iterable<SourceWorkspaceFile> files)
    : files = List.unmodifiable(files);
  final String root;
  final List<SourceWorkspaceFile> files;
}

abstract interface class SourceWorkspaceGateway {
  Future<String?> chooseRoot();
  Future<SourceWorkspaceScan> scan(String root);
  Future<SourceWorkspaceFile> read(String root, String relativePath);

  /// Explicit Save only. Validate expected bytes, retain a backup, and never
  /// overwrite a file that changed outside this workspace.
  Future<SourceWorkspaceFile> save(
    String root,
    String relativePath,
    String text,
    String expectedRevision,
  );
}
