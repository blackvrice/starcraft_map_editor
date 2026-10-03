import 'package:flutter/material.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/settings/eud_tool_settings_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_source_editor.dart';
import 'package:starcraft_map_editor/presentation/resources/resources_pane.dart';
import 'package:starcraft_map_editor/presentation/settings/eud_tool_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/force_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/map_information_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/player_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/tech_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/unit_availability_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/unit_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/upgrade_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/triggers/trigger_resource_dialog.dart';

import 'eud_project_workspace_fixture.dart';

/// Synthetic bytes and in-memory services only, also used by Windows render QA.
class LocalizationFixture {
  LocalizationFixture() {
    workspace.maps.createNew(
      NewMapOptions(width: 32, height: 32, rawTileValue: 0, title: 'Map'),
      expectedSession: null,
    );
    editing = ObjectEditingController(
      openMapController: workspace.maps,
      mapLayerController: layers,
    );
    sources.createUntitled(initialText: '// User source stays English');
    tools = EudToolSettingsController(
      store: InMemorySettingsStore(),
      inspector: LocalizationToolInspector(),
    );
  }

  final workspace = EudWorkspaceFixture();
  final layers = MapLayerController();
  final sources = EudSourceController();
  late final ObjectEditingController editing;
  late final EudToolSettingsController tools;

  List<({String name, String heading, Widget widget})> get screens => [
    (
      name: 'map',
      heading: '맵 정보',
      widget: MapInformationDialog(controller: editing),
    ),
    (
      name: 'players',
      heading: '플레이어 설정',
      widget: PlayerSettingsDialog(controller: editing),
    ),
    (
      name: 'forces',
      heading: '세력 설정',
      widget: ForceSettingsDialog(controller: editing),
    ),
    (
      name: 'units',
      heading: '유닛 설정',
      widget: UnitSettingsDialog(controller: editing),
    ),
    (
      name: 'availability',
      heading: '유닛 사용 가능 여부',
      widget: UnitAvailabilityDialog(controller: editing),
    ),
    (
      name: 'upgrades',
      heading: '업그레이드 설정',
      widget: UpgradeSettingsDialog(controller: editing),
    ),
    (
      name: 'tech',
      heading: '기술 설정',
      widget: TechSettingsDialog(controller: editing),
    ),
    (
      name: 'resources',
      heading: '리소스',
      widget: ResourcesPane(controller: editing, active: true),
    ),
    (
      name: 'briefing-properties',
      heading: '유닛 속성 슬롯',
      widget: TriggerResourceDialog(
        document: workspace.maps.state.session!.rawDocument,
        kind: TriggerResourceKind.property,
      ),
    ),
    (
      name: 'tools',
      heading: 'EUD 도구',
      widget: EudToolSettingsDialog(controller: tools),
    ),
    (
      name: 'source',
      heading: '메모리 초안',
      widget: EudSourceEditor(
        document: sources.state.document!,
        sourceController: sources,
      ),
    ),
  ];

  Future<void> dispose() async {
    await editing.dispose();
    await layers.dispose();
    sources.dispose();
    await tools.dispose();
    workspace.dispose();
  }
}

class LocalizationToolInspector implements EudToolInspector {
  @override
  Future<EudToolInspectionResult> inspect(
    EudToolInspectionRequest request,
  ) async => EudToolInspectionResult.failure(
    diagnostics: const [
      EditorDiagnostic(
        code: 'EUD_TOOL_COMPANION_MISSING',
        message: 'The euddraft installation is incomplete.',
        messageId: 'editorTheEuddraftInstallationIsIncomplete',
        remediation: 'Re-extract the complete official euddraft release.',
        remediationId: 'editorReExtractTheCompleteOfficialEuddraftRelease',
        severity: DiagnosticSeverity.error,
        stage: DiagnosticStage.compile,
        rawDetails: 'missing=lib/freezeMpq.pyd; stdout=Map opened',
      ),
    ],
  );
}
