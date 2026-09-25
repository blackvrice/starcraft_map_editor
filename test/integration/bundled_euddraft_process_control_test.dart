import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/bundled_eud_tool.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_compiler_gateway.dart';

void main() {
  final installation = Platform.environment['EUDDRAFT_TEST_INSTALLATION'];
  final enabled =
      Platform.isWindows &&
      installation != null &&
      Platform.environment['EUDDRAFT_TEST_BUNDLED'] == '1';
  for (final cancel in [true, false]) {
    test(
      'managed compiler ${cancel ? 'cancellation' : 'timeout'} stops execution',
      () async {
        final inspector = BundledEudTool.inspector();
        final inspectionRequest = EudToolInspectionRequest(
          bundledPath: installation,
        );
        final inspection = await inspector.inspect(inspectionRequest);
        expect(inspection.isReady, isTrue);
        final root = await Directory.systemTemp.createTemp(
          'managed-eud-control-',
        );
        addTearDown(() => root.delete(recursive: true));
        final source = File('${root.path}/wait.py');
        await source.writeAsString(
          'import time\nprint("MANAGED_TEST_WAIT", flush=True)\ntime.sleep(60)\n',
        );
        final map = File(
          'test/fixtures/maps/eud_smoke/eud-smoke-self-authored.scx',
        ).absolute;
        final output = File('${root.path}/output.scx');
        final settings = File('${root.path}/build.eds');
        await settings.writeAsString(
          '[main]\ninput: ${map.path}\noutput: ${output.path}\n'
          '[freeze]\nfreeze: 0\n[${source.path}]\n',
        );
        final gateway = ProcessEudCompilerGateway();
        final request = EudBuildRequest(
          buildId: 'managed-control',
          tool: inspection.tool!,
          settingsFilePath: settings.path,
          timeout: Duration(seconds: cancel ? 20 : 5),
        );
        var reachedPlugin = false;
        final events = <EudBuildEvent>[];
        await for (final event in gateway.build(request)) {
          events.add(event);
          if (event.text?.contains('MANAGED_TEST_WAIT') ?? false) {
            reachedPlugin = true;
            if (cancel) expect(await gateway.cancel(request.buildId), isTrue);
          }
        }
        expect(reachedPlugin, isTrue, reason: '${events.map((e) => e.text)}');
        expect(
          events.last.kind,
          cancel ? EudBuildEventKind.cancelled : EudBuildEventKind.failed,
        );
        expect(
          events.last.diagnostic!.code,
          cancel
              ? EudCompilerDiagnosticCodes.cancelled
              : EudCompilerDiagnosticCodes.timedOut,
        );
        expect(await output.exists(), isFalse);
        expect((await inspector.inspect(inspectionRequest)).isReady, isTrue);
      },
      skip: !enabled,
      timeout: const Timeout(Duration(seconds: 45)),
    );
  }
}
