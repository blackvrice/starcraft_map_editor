import '../../domain/eud/source_workspace_index.dart';
import 'eud_source_document.dart';

final class SourceWorkspaceRecovery {
  SourceWorkspaceRecovery({
    required this.root,
    required this.activeId,
    required Iterable<EudSourceDocument> documents,
  }) : documents = List.unmodifiable(documents) {
    if (this.documents.isEmpty ||
        this.documents.any(
          (d) =>
              d.documentId.length > 128 ||
              d.fileName.length > 255 ||
              d.text.length > 4 * 1024 * 1024 ||
              d.savedText.length > 4 * 1024 * 1024,
        ) ||
        this.documents.length > 16 ||
        this.documents.map((d) => d.documentId).toSet().length !=
            this.documents.length ||
        !this.documents.any((d) => d.documentId == activeId) ||
        this.documents.fold<int>(
              0,
              (n, d) => n + d.text.length + d.savedText.length,
            ) >
            32 * 1024 * 1024 ||
        (root != null &&
            (root!.length > 4096 ||
                root!.contains(RegExp(r'[\x00-\x1f]')) ||
                !RegExp(
                  r'^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+)',
                ).hasMatch(root!) ||
                root!
                    .split(RegExp(r'[\\/]'))
                    .any((p) => p == '.' || p == '..')))) {
      throw const FormatException('SOURCE_RECOVERY_INVALID');
    }
    final paths = this.documents
        .where((d) => d.sourcePath != null)
        .map((d) => SourcePaths.key(d.sourcePath!))
        .toList();
    if (paths.toSet().length != paths.length) {
      throw const FormatException('SOURCE_RECOVERY_DUPLICATE_PATH');
    }
    if (root != null &&
        paths.any((p) => !p.startsWith('${SourcePaths.key(root!)}/'))) {
      throw const FormatException('SOURCE_RECOVERY_OUTSIDE_ROOT');
    }
  }
  final String? root;
  final String activeId;
  final List<EudSourceDocument> documents;
  Map<String, Object?> toJson() => {
    'root': root,
    'activeId': activeId,
    'documents': documents
        .map(
          (d) => {
            'id': d.documentId,
            'fileName': d.fileName,
            'path': d.sourcePath,
            'savedText': d.savedText,
            'text': d.text,
          },
        )
        .toList(),
  };
  factory SourceWorkspaceRecovery.fromJson(Map<String, dynamic> json) {
    final entries = json['documents'] as List<dynamic>;
    if (entries.length > 16) {
      throw const FormatException('SOURCE_RECOVERY_LIMIT');
    }
    return SourceWorkspaceRecovery(
      root: json['root'] as String?,
      activeId: json['activeId'] as String,
      documents: entries.map((raw) {
        final e = raw as Map<String, dynamic>,
            saved = e['savedText'] as String,
            text = e['text'] as String;
        if (saved.length > 4 * 1024 * 1024 || text.length > 4 * 1024 * 1024) {
          throw const FormatException('SOURCE_RECOVERY_LIMIT');
        }
        return (e['path'] == null
                ? EudSourceDocument.untitled(
                    documentId: e['id'] as String,
                    fileName: e['fileName'] as String,
                    initialText: saved,
                  )
                : EudSourceDocument.opened(
                    documentId: e['id'] as String,
                    sourcePath: e['path'] as String,
                    text: saved,
                  ))
            .withText(text);
      }),
    );
  }
}
