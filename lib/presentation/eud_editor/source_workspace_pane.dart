import 'package:flutter/material.dart';
import '../../application/eud/eud_source_controller.dart';
import '../../domain/eud/source_workspace_index.dart';
import '../localization/l10n.dart';
import 'eud_source_editor.dart';

Future<void> sourceAction(
  BuildContext context,
  Future<Object?> Function() action,
) async {
  try {
    await action();
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class SourceWorkspaceNavigator extends StatelessWidget {
  const SourceWorkspaceNavigator({
    required this.controller,
    required this.onSelected,
    super.key,
  });
  final EudSourceController controller;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  controller.root ?? context.l10n.sourceProjectFolder,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              key: const Key('source-root-open'),
              tooltip: context.l10n.sourceProjectFolder,
              onPressed:
                  controller.workspaceBusy ||
                      controller.workspaceGateway == null
                  ? null
                  : () => sourceAction(context, controller.chooseWorkspace),
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            key: const Key('eud-source-list'),
            children: [
              ...controller.documents
                  .where((d) => d.sourcePath == null || controller.root == null)
                  .map(
                    (d) => ListTile(
                      dense: true,
                      selected:
                          controller.state.document?.documentId == d.documentId,
                      leading: const Icon(Icons.code, size: 18),
                      title: Text(
                        '${d.fileName}${d.isDirty ? ' *' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        controller.activate(d.documentId);
                        onSelected();
                      },
                    ),
                  ),
              ..._tree(context, ''),
            ],
          ),
        ),
      ],
    ),
  );
  List<Widget> _tree(BuildContext context, String prefix) {
    final files = controller.workspaceFiles
        .where((f) => f.relativePath.startsWith(prefix))
        .toList();
    final folders = <String>{};
    final children = <Widget>[];
    for (final f in files) {
      final rest = f.relativePath.substring(prefix.length),
          slash = rest.indexOf('/');
      if (slash >= 0) {
        final folder = rest.substring(0, slash);
        if (folders.add(folder)) {
          children.add(
            ExpansionTile(
              key: PageStorageKey('$prefix$folder'),
              initiallyExpanded: true,
              dense: true,
              leading: const Icon(Icons.folder_outlined, size: 18),
              title: Text(folder, maxLines: 1, overflow: TextOverflow.ellipsis),
              children: _tree(context, '$prefix$folder/'),
            ),
          );
        }
      } else {
        final doc = controller.documents
            .where((d) => d.sourcePath == f.path)
            .firstOrNull;
        children.add(
          ListTile(
            key: Key('source-file-${f.relativePath}'),
            dense: true,
            selected:
                doc != null &&
                doc.documentId == controller.state.document?.documentId,
            leading: Icon(
              doc != null && controller.conflicts.contains(doc.documentId)
                  ? Icons.warning_amber
                  : Icons.description_outlined,
              size: 18,
            ),
            title: Text(
              '$rest${doc?.isDirty == true ? ' *' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: controller.workspaceBusy
                ? null
                : () => sourceAction(context, () async {
                    await controller.openRelative(f.relativePath);
                    onSelected();
                    return true;
                  }),
          ),
        );
      }
    }
    return children;
  }
}

class SourceWorkspacePane extends StatelessWidget {
  const SourceWorkspacePane({required this.controller, super.key});
  final EudSourceController controller;
  Future<void> _close(BuildContext context, String id) async {
    if (controller.closeTab(id)) return;
    if (controller.workspaceBusy) return;
    if (await _confirm(context) == true && context.mounted) {
      controller.closeTab(id, discardChanges: true);
    }
  }

  Future<bool?> _confirm(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.sourceDiscardChanges),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.eudCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10n.sourceDiscard),
        ),
      ],
    ),
  );
  Future<void> _search(BuildContext context) async {
    await controller.rebuildIndex();
    if (!context.mounted) return;
    final query = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            final hits =
                controller.index?.search(query.text) ?? <SourceSearchHit>[];
            return AlertDialog(
              title: Text(ctx.l10n.sourceSearchProject),
              content: SizedBox(
                width: 720,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('source-project-query'),
                      controller: query,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: ctx.l10n.sourceSearchText,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: hits.length,
                        itemBuilder: (ctx, i) {
                          final hit = hits[i];
                          return ListTile(
                            key: Key('source-search-hit-$i'),
                            dense: true,
                            title: Text(
                              '${hit.path}:${hit.line}:${hit.column}',
                            ),
                            subtitle: Text(
                              hit.excerpt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => sourceAction(ctx, () async {
                              await controller.navigate(
                                hit.path,
                                hit.line,
                                column: hit.column,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              return true;
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(ctx.l10n.eudCancel),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      query.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = controller.documents, active = controller.state.document;
    final busy = controller.workspaceBusy, root = controller.root;
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.sourceProjectFolder,
                    onPressed: busy || controller.workspaceGateway == null
                        ? null
                        : () =>
                              sourceAction(context, controller.chooseWorkspace),
                    icon: const Icon(Icons.folder_open),
                  ),
                  IconButton(
                    key: const Key('source-project-refresh'),
                    tooltip: context.l10n.sourceRefreshProject,
                    onPressed: busy || root == null
                        ? null
                        : () => sourceAction(
                            context,
                            controller.refreshWorkspace,
                          ),
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    key: const Key('source-new-tab'),
                    tooltip: context.l10n.sourceNewTab,
                    onPressed: busy ? null : () => controller.newTab(),
                    icon: const Icon(Icons.note_add_outlined),
                  ),
                  IconButton(
                    key: const Key('source-project-search'),
                    tooltip: context.l10n.sourceSearchProject,
                    onPressed: busy || !controller.workspaceVerified
                        ? null
                        : () => _search(context),
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    key: const Key('source-save-active'),
                    tooltip: context.l10n.sourceSaveFile,
                    onPressed:
                        busy ||
                            !controller.workspaceVerified ||
                            controller.relativeFor(active?.sourcePath) ==
                                null ||
                            controller.conflicts.contains(active?.documentId)
                        ? null
                        : () => sourceAction(context, controller.saveActive),
                    icon: const Icon(Icons.save_outlined),
                  ),
                  IconButton(
                    key: const Key('source-reload-active'),
                    tooltip: context.l10n.sourceReloadFile,
                    onPressed:
                        busy ||
                            !controller.workspaceVerified ||
                            controller.relativeFor(active?.sourcePath) == null
                        ? null
                        : () => sourceAction(context, () async {
                            if (active!.isDirty &&
                                await _confirm(context) != true) {
                              return false;
                            }
                            return controller.reloadActive(
                              discardChanges: true,
                            );
                          }),
                    icon: const Icon(Icons.restore_page_outlined),
                  ),
                  if (controller.indexPending)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
          if (root != null && !controller.workspaceVerified)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(context.l10n.sourceVerifyRestoredRoot),
            ),
          if (controller.conflicts.isNotEmpty)
            Padding(
              key: const Key('source-conflict-banner'),
              padding: const EdgeInsets.all(6),
              child: Text(context.l10n.sourceExternalConflict),
            ),
          if (controller.workspaceError case final error?)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(error, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          SizedBox(
            height: 36,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final doc in docs)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          key: Key('source-tab-${doc.documentId}'),
                          onPressed: () => controller.activate(doc.documentId),
                          style: TextButton.styleFrom(
                            backgroundColor:
                                doc.documentId == active?.documentId
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest
                                : null,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              '${doc.fileName}${doc.isDirty || doc.isUntitled ? ' *' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          key: Key('source-close-${doc.documentId}'),
                          tooltip: context.l10n.sourceCloseTab,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: busy
                              ? null
                              : () => _close(context, doc.documentId),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          if (docs.isNotEmpty)
            Expanded(
              child: IndexedStack(
                index: docs.indexWhere(
                  (d) => d.documentId == active?.documentId,
                ),
                children: [
                  for (final doc in docs)
                    EudSourceEditor(
                      key: ValueKey(doc.documentId),
                      document: doc,
                      sourceController: controller,
                    ),
                ],
              ),
            )
          else
            const Expanded(child: SizedBox()),
          if (controller.index case final index? when index.issues.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView(
                children: [
                  for (final issue in index.issues)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.warning_amber, size: 16),
                      title: Text(
                        '${issue.code}: ${issue.path}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        issue.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => sourceAction(context, () async {
                        final before = index.texts[issue.path]!.substring(
                          0,
                          issue.offset,
                        );
                        final line = '\n'.allMatches(before).length + 1;
                        return controller.navigate(
                          issue.path,
                          line,
                          column: issue.offset - before.lastIndexOf('\n'),
                        );
                      }),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
