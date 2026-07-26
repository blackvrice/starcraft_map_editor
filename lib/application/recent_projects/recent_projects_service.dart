import 'dart:convert';

import '../ports/settings_store.dart';
import 'recent_project.dart';

class RecentProjectsService {
  RecentProjectsService(this._settingsStore, {this.maximumProjects = 8})
    : assert(maximumProjects > 0);

  static const _settingsKey = 'recentProjects';

  final SettingsStore _settingsStore;
  final int maximumProjects;

  Future<List<RecentProject>> load() async {
    final storedValue = await _settingsStore.readString(_settingsKey);
    if (storedValue == null || storedValue.isEmpty) {
      return const [];
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(storedValue);
    } on FormatException {
      return const [];
    }

    if (decoded is! List<dynamic>) {
      return const [];
    }

    final projects = <RecentProject>[];
    final knownPaths = <String>{};
    for (final entry in decoded) {
      final project = RecentProject.fromJson(entry);
      if (project == null || !knownPaths.add(_pathKey(project.path))) {
        continue;
      }
      projects.add(project);
    }

    projects.sort((left, right) {
      return right.lastOpenedAt.compareTo(left.lastOpenedAt);
    });

    return List.unmodifiable(projects.take(maximumProjects));
  }

  Future<List<RecentProject>> recordOpened(
    String path, {
    DateTime? openedAt,
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Path must not be empty.');
    }

    final projects = (await load()).toList();
    projects.removeWhere(
      (project) => _pathKey(project.path) == _pathKey(normalizedPath),
    );
    projects.insert(
      0,
      RecentProject(
        path: normalizedPath,
        lastOpenedAt: openedAt ?? DateTime.now(),
      ),
    );

    final limitedProjects = projects.take(maximumProjects).toList();
    await _save(limitedProjects);
    return List.unmodifiable(limitedProjects);
  }

  Future<List<RecentProject>> remove(String path) async {
    final projects = (await load()).toList()
      ..removeWhere((project) => _pathKey(project.path) == _pathKey(path));
    await _save(projects);
    return List.unmodifiable(projects);
  }

  Future<void> _save(List<RecentProject> projects) {
    final encoded = jsonEncode(
      projects.map((project) => project.toJson()).toList(),
    );
    return _settingsStore.writeString(_settingsKey, encoded);
  }

  String _pathKey(String path) =>
      path.trim().replaceAll('/', '\\').toLowerCase();
}
