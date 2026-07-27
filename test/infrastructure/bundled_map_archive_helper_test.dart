import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';

void main() {
  final helperPath = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  final mapPath =
      Platform.environment['MAP_ARCHIVE_TEST_MAP'] ??
      'test/fixtures/maps/generated/minimal-self-authored.scx';
  final missingEnvironment =
      helperPath == null || helperPath.isEmpty || mapPath.isEmpty;

  test(
    'bundled helper extracts, replaces, and reopens without changing source',
    () async {
      final sourceFile = File(mapPath);
      final sourceBytesBefore = await sourceFile.readAsBytes();
      final expectedScenarioChk = _loadHexFixture(
        'test/fixtures/chk/metadata.chk.hex',
      );
      final gateway = ProcessMapArchiveGateway(
        helperExecutablePath: helperPath!,
      );
      final saveWorkspace = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_bundled_save_',
      );
      addTearDown(() async {
        if (await saveWorkspace.exists()) {
          await saveWorkspace.delete(recursive: true);
        }
      });

      final result = await gateway.open(
        MapArchiveOpenRequest(
          operationId: 'bundled-helper-smoke',
          sourcePath: sourceFile.path,
          timeout: const Duration(seconds: 30),
        ),
      );
      final sourceBytesAfter = await sourceFile.readAsBytes();

      expect(
        result.isSuccess,
        isTrue,
        reason: result.diagnostics
            .map(
              (diagnostic) =>
                  '${diagnostic.code}:${diagnostic.message}:'
                  '${diagnostic.rawDetails}',
            )
            .join('\n'),
      );
      expect(result.extractedMap?.scenarioChkBytes, expectedScenarioChk);
      expect(result.extractedMap?.metadata.formatVersion, 1);
      expect(result.extractedMap?.metadata.totalEntryCount, 3);
      expect(result.extractedMap?.metadata.listingComplete, isTrue);
      expect(
        result.extractedMap?.metadata.entries
            .map((entry) => entry.path)
            .toSet(),
        {MapArchiveEntryPaths.scenarioChk, r'staredit\units.dat', '(listfile)'},
      );
      expect(result.diagnostics, isEmpty);
      expect(sourceBytesAfter, sourceBytesBefore);

      final temporaryOutputPath =
          '${saveWorkspace.path}${Platform.pathSeparator}saved.scx';
      final replacementChk = [...expectedScenarioChk]..[20] = 59;
      final writeResult = await gateway.writeTemporary(
        MapArchiveWriteRequest(
          operationId: 'bundled-helper-write-smoke',
          sourcePath: sourceFile.path,
          temporaryOutputPath: temporaryOutputPath,
          scenarioChkBytes: replacementChk,
          timeout: const Duration(seconds: 30),
        ),
      );
      expect(
        writeResult.isSuccess,
        isTrue,
        reason: '${writeResult.diagnostics}',
      );

      final reopened = await gateway.open(
        MapArchiveOpenRequest(
          operationId: 'bundled-helper-reopen-smoke',
          sourcePath: temporaryOutputPath,
          timeout: const Duration(seconds: 30),
        ),
      );

      expect(reopened.isSuccess, isTrue, reason: '${reopened.diagnostics}');
      expect(reopened.extractedMap?.scenarioChkBytes, replacementChk);
      expect(
        reopened.extractedMap?.metadata.entries
            .map((entry) => entry.path)
            .toSet(),
        {MapArchiveEntryPaths.scenarioChk, r'staredit\units.dat', '(listfile)'},
      );
      expect(await sourceFile.readAsBytes(), sourceBytesBefore);
    },
    skip: missingEnvironment
        ? 'Set MAP_ARCHIVE_HELPER_PATH after building the Windows app.'
        : false,
  );
}

List<int> _loadHexFixture(String path) {
  final bytes = <int>[];
  for (final line in File(path).readAsLinesSync()) {
    final content = line.split('#').first.trim();
    if (content.isEmpty) {
      continue;
    }
    for (final token in content.split(RegExp(r'\s+'))) {
      bytes.add(int.parse(token, radix: 16));
    }
  }
  return bytes;
}
