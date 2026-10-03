import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
import 'package:flutter/material.dart';

import '../../application/ports/starcraft_data_asset_inspector.dart';
import '../../application/settings/starcraft_data_asset_settings_controller.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

class StarCraftAssetSettingsDialog extends StatelessWidget {
  const StarCraftAssetSettingsDialog({required this.controller, super.key});

  final StarCraftDataAssetSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StarCraftDataAssetSettingsState>(
      initialData: controller.state,
      stream: controller.changes,
      builder: (context, snapshot) {
        final state = snapshot.data ?? controller.state;
        return AlertDialog(
          key: const Key('starcraft-asset-settings-dialog'),
          title: Row(
            children: [
              Icon(Icons.landscape_outlined, color: Color(0xFF70A1FF)),
              SizedBox(width: 10),
              Text(context.l10n.editorStarCraftDataAssets),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context
                        .l10n
                        .editorChooseTheInstalledStarCraftRemasteredDirectoryTheEditorReads,
                    style: TextStyle(color: Color(0xFFB4BECE)),
                  ),
                  const SizedBox(height: 14),
                  _AssetPathCard(state: state),
                  const SizedBox(height: 12),
                  _AssetInspectionSummary(state: state),
                  if (state.inspection case final inspection?)
                    if (inspection.storageProduct != null) ...[
                      const SizedBox(height: 8),
                      _CascStorageMetadata(inspection: inspection),
                    ],
                  if (state.diagnostics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _AssetDiagnosticSummary(diagnostics: state.diagnostics),
                  ],
                  if (state.inspection case final inspection?)
                    if (inspection.missingRelativePaths.isNotEmpty ||
                        inspection.invalidRelativePaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _MissingAssetList(
                        missingPaths: inspection.missingRelativePaths,
                        invalidPaths: inspection.invalidRelativePaths,
                      ),
                    ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('starcraft-assets-clear'),
              onPressed: state.configuredPath == null || state.isBusy
                  ? null
                  : () => controller.clear(),
              child: Text(context.l10n.editorClear),
            ),
            TextButton.icon(
              key: const Key('starcraft-assets-refresh'),
              onPressed: state.configuredPath == null || state.isBusy
                  ? null
                  : () => controller.refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.editorRefresh),
            ),
            FilledButton.icon(
              key: const Key('starcraft-assets-choose'),
              onPressed: state.isBusy
                  ? null
                  : () => controller.chooseDirectory(),
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(context.l10n.editorChooseInstallation),
            ),
            TextButton(
              key: const Key('starcraft-assets-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.editorClose),
            ),
          ],
        );
      },
    );
  }
}

class _CascStorageMetadata extends StatelessWidget {
  const _CascStorageMetadata({required this.inspection});

  final StarCraftDataAssetInspection inspection;

  @override
  Widget build(BuildContext context) {
    final revision = inspection.cascLibRevision;
    final revisionLabel = revision == null
        ? context.l10n.editorUnknown
        : revision.substring(0, revision.length < 8 ? revision.length : 8);
    final totalMiB = inspection.totalAssetBytes / (1024 * 1024);
    return Text(
      context.l10n.editorCASCBuildMiBCheckedCascLibHelper(
        (inspection.storageProduct).toString(),
        (inspection.storageBuildNumber ?? 0).toString(),
        (totalMiB.toStringAsFixed(1)).toString(),
        (revisionLabel).toString(),
        (inspection.helperVersion ?? context.l10n.editorUnknown).toString(),
      ),
      key: const Key('starcraft-assets-casc-metadata'),
      style: const TextStyle(
        color: Color(0xFF8994A8),
        fontFamily: 'monospace',
        fontSize: 11,
      ),
    );
  }
}

class _AssetPathCard extends StatelessWidget {
  const _AssetPathCard({required this.state});

  final StarCraftDataAssetSettingsState state;

  @override
  Widget build(BuildContext context) {
    final path = state.configuredPath;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF303949)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.editorConfiguredPath,
              style: TextStyle(
                color: Color(0xFF8994A8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(
              path ?? context.l10n.editorNotConfigured,
              key: const Key('starcraft-assets-path'),
              style: TextStyle(
                color: path == null
                    ? const Color(0xFFFFC56E)
                    : const Color(0xFFE1E7F0),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              context
                  .l10n
                  .editorExpectedTheFolderContainingStarCraftExeBuildInfoAnd,
              style: TextStyle(color: Color(0xFF7F8A9C), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetInspectionSummary extends StatelessWidget {
  const _AssetInspectionSummary({required this.state});

  final StarCraftDataAssetSettingsState state;

  @override
  Widget build(BuildContext context) {
    final inspection = state.inspection;
    final (icon, color, label) = switch (state.status) {
      StarCraftDataAssetSettingsStatus.loading => (
        Icons.hourglass_top_rounded,
        const Color(0xFF8EA0BB),
        context.l10n.editorLoadingSettings,
      ),
      StarCraftDataAssetSettingsStatus.inspecting => (
        Icons.search_rounded,
        const Color(0xFF8EA0BB),
        context.l10n.editorInspectingAssets,
      ),
      StarCraftDataAssetSettingsStatus.ready => (
        Icons.check_circle_outline_rounded,
        const Color(0xFF7ADAA5),
        context.l10n.editorRequiredAssetsReady(
          (inspection?.foundAssetCount ?? 0).toString(),
          (inspection?.requiredAssetCount ?? 0).toString(),
        ),
      ),
      StarCraftDataAssetSettingsStatus.unconfigured => (
        Icons.settings_outlined,
        const Color(0xFFFFC56E),
        context.l10n.editorStarCraftInstallationIsNotConfigured,
      ),
      StarCraftDataAssetSettingsStatus.unavailable => (
        Icons.warning_amber_rounded,
        const Color(0xFFFFB454),
        inspection == null
            ? context.l10n.editorStarCraftCASCDataIsUnavailable
            : context.l10n.editorRequiredAssetsFound(
                (inspection.foundAssetCount).toString(),
                (inspection.requiredAssetCount).toString(),
              ),
      ),
    };

    return Row(
      key: const Key('starcraft-assets-status'),
      children: [
        if (state.isBusy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Icon(icon, color: color, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AssetDiagnosticSummary extends StatelessWidget {
  const _AssetDiagnosticSummary({required this.diagnostics});

  final List<EditorDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF251E17),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF574123)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final diagnostic in diagnostics) ...[
              Text(
                '[${diagnostic.code}] ${context.diagnosticMessage(diagnostic)}',
                style: const TextStyle(color: Color(0xFFFFD18A), fontSize: 12),
              ),
              if (context.diagnosticRemediation(diagnostic)
                  case final remediation?)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    remediation,
                    style: const TextStyle(
                      color: Color(0xFFB9A98F),
                      fontSize: 11,
                    ),
                  ),
                ),
              if (diagnostic != diagnostics.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingAssetList extends StatelessWidget {
  const _MissingAssetList({
    required this.missingPaths,
    required this.invalidPaths,
  });

  final List<String> missingPaths;
  final List<String> invalidPaths;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final path in missingPaths)
        (path: path, label: context.l10n.editorMissing),
      for (final path in invalidPaths)
        (path: path, label: context.l10n.editorInvalid),
    ];
    const maximumVisibleEntries = 8;
    final visibleEntries = entries.take(maximumVisibleEntries).toList();
    final remaining = entries.length - visibleEntries.length;

    return DecoratedBox(
      key: const Key('starcraft-assets-missing-list'),
      decoration: BoxDecoration(
        color: const Color(0xFF141820),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3240)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.editorUnavailableAssetFiles,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final entry in visibleEntries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        entry.label,
                        style: const TextStyle(
                          color: Color(0xFFFFB454),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.path,
                        style: const TextStyle(
                          color: Color(0xFFB7C0CF),
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  context.l10n.editorAndMore((remaining).toString()),
                  style: const TextStyle(
                    color: Color(0xFF8994A8),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
