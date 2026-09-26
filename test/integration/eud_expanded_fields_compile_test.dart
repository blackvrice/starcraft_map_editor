import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/domain/eud/eud_field_manifest.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/bundled_eud_tool.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_compiler_gateway.dart';

void main() {
  final installation = Platform.environment['EUDDRAFT_TEST_INSTALLATION'];
  test(
    'all candidate fields and enum choices compile with the pinned bundle',
    () async {
      final inspector = BundledEudTool.inspector();
      final inspectionRequest = EudToolInspectionRequest(
        bundledPath: installation,
      );
      final inspection = await inspector.inspect(inspectionRequest);
      expect(inspection.isReady, isTrue);
      final root = await Directory.systemTemp.createTemp('eud-fields-');
      addTearDown(() => root.delete(recursive: true));
      final lines = ['from eudplib import *', 'def onPluginStart():'];
      for (final field in EudFieldManifest.fields) {
        final parts = field.member.split('.');
        final values = switch (field.type) {
          EudValueType.boolean => <Object>[true, false],
          EudValueType.enumeration => field.choices,
          EudValueType.unsignedInteger => <Object>[
            0,
            field.allowedBits ?? field.valueMaximum,
          ],
        };
        for (final target in {0, field.targetCount - 1}) {
          for (final value in values) {
            final literal = value is bool
                ? (value ? 'True' : 'False')
                : jsonEncode(value);
            lines.add('    ${parts.first}($target).${parts.last} = $literal');
          }
        }
      }
      lines.add('    print("ALL_EUD_FIELDS_COMPILED", flush=True)');
      final source = File('${root.path}/fields.py');
      await source.writeAsString('${lines.join('\n')}\n');
      final map = File(
        'test/fixtures/maps/eud_smoke/eud-smoke-self-authored.scx',
      ).absolute;
      final original = await map.readAsBytes();
      final output = File('${root.path}/compiled.scx');
      final settings = File('${root.path}/build.eds');
      await settings.writeAsString(
        '[main]\ninput: ${map.path}\noutput: ${output.path}\n[freeze]\nfreeze: 0\n[${source.path}]\n',
      );
      final events = await ProcessEudCompilerGateway()
          .build(
            EudBuildRequest(
              buildId: 'candidate-fields',
              tool: inspection.tool!,
              settingsFilePath: settings.path,
              timeout: const Duration(seconds: 90),
            ),
          )
          .toList();
      final log = events
          .map((e) => e.text ?? e.diagnostic?.message ?? '')
          .join('\n');
      expect(events.last.kind, EudBuildEventKind.succeeded, reason: log);
      expect(log, contains('ALL_EUD_FIELDS_COMPILED'));
      expect(await output.length(), greaterThan(0));
      expect(await map.readAsBytes(), original);
      expect((await inspector.inspect(inspectionRequest)).isReady, isTrue);
    },
    skip:
        !Platform.isWindows ||
        installation == null ||
        Platform.environment['EUDDRAFT_TEST_BUNDLED'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
