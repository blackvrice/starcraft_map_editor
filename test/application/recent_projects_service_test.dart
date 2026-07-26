import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  test('stores recent maps in most-recent-first order', () async {
    final service = RecentProjectsService(InMemorySettingsStore());

    await service.recordOpened(
      r'C:\Maps\First.scx',
      openedAt: DateTime.utc(2026, 7, 25, 10),
    );
    await service.recordOpened(
      r'C:\Maps\Second.scx',
      openedAt: DateTime.utc(2026, 7, 26, 10),
    );

    final projects = await service.load();

    expect(projects.map((project) => project.path), [
      r'C:\Maps\Second.scx',
      r'C:\Maps\First.scx',
    ]);
  });

  test(
    'deduplicates Windows paths and enforces the configured limit',
    () async {
      final service = RecentProjectsService(
        InMemorySettingsStore(),
        maximumProjects: 2,
      );

      await service.recordOpened(r'C:\Maps\First.scx');
      await service.recordOpened(r'C:\Maps\Second.scx');
      await service.recordOpened('c:/maps/FIRST.scx');

      final projects = await service.load();

      expect(projects, hasLength(2));
      expect(projects.first.path, 'c:/maps/FIRST.scx');
      expect(
        projects.where(
          (project) =>
              project.path.replaceAll('/', '\\').toLowerCase() ==
              r'c:\maps\first.scx',
        ),
        hasLength(1),
      );
    },
  );

  test('ignores malformed stored state', () async {
    final settings = InMemorySettingsStore({
      'recentProjects': '{"not": "a list"}',
    });

    final projects = await RecentProjectsService(settings).load();

    expect(projects, isEmpty);
  });
}
