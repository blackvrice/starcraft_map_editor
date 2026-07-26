import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';

void main() {
  final helperPath = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  final mapPath = Platform.environment['MAP_ARCHIVE_TEST_MAP'];
  final missingEnvironment =
      helperPath == null ||
      helperPath.isEmpty ||
      mapPath == null ||
      mapPath.isEmpty;

  test(
    'bundled helper extracts a self-created MPQ without changing its source',
    () async {
      final sourceFile = File(mapPath!);
      final sourceBytesBefore = await sourceFile.readAsBytes();
      final gateway = ProcessMapArchiveGateway(
        helperExecutablePath: helperPath!,
      );

      final result = await gateway.open(
        MapArchiveOpenRequest(
          operationId: 'bundled-helper-smoke',
          sourcePath: sourceFile.path,
          timeout: const Duration(seconds: 30),
        ),
      );
      final sourceBytesAfter = await sourceFile.readAsBytes();

      expect(result.isSuccess, isTrue, reason: '${result.diagnostics}');
      expect(result.extractedMap?.scenarioChkBytes, [
        86,
        69,
        82,
        32,
        2,
        0,
        0,
        0,
        59,
        0,
      ]);
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
    },
    skip: missingEnvironment
        ? 'Set MAP_ARCHIVE_HELPER_PATH and MAP_ARCHIVE_TEST_MAP after build.'
        : false,
  );
}
