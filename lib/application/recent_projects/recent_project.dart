class RecentProject {
  const RecentProject({required this.path, required this.lastOpenedAt});

  final String path;
  final DateTime lastOpenedAt;

  Map<String, Object> toJson() => {
    'path': path,
    'lastOpenedAt': lastOpenedAt.toUtc().toIso8601String(),
  };

  static RecentProject? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final path = value['path'];
    final lastOpenedAt = value['lastOpenedAt'];
    if (path is! String || path.isEmpty || lastOpenedAt is! String) {
      return null;
    }

    final parsedDate = DateTime.tryParse(lastOpenedAt);
    if (parsedDate == null) {
      return null;
    }

    return RecentProject(path: path, lastOpenedAt: parsedDate.toLocal());
  }
}
