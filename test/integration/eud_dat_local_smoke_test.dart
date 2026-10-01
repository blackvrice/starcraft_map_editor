import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_eud_dat_gateway.dart';

void main() {
  final path = Platform.environment['STARCRAFT_TEST_INSTALLATION'],
      helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  test(
    'reads local fixed DAT defaults and complete references with source hashes',
    () async {
      final result = await ProcessEudDatGateway(
        helperExecutablePath: helper!,
      ).read(operationId: 'eud-real', installationPath: path!);
      expect(
        result.isSuccess,
        isTrue,
        reason: '${result.errorCode}\n${result.stderr}',
      );
      final data = result.source!;
      expect(data.hashes, hasLength(7));
      expect(data.snapshot.columns, hasLength(61));
      expect(data.snapshot.weaponIndex().units, hasLength(228));
      expect(data.snapshot.graph().unresolved, isEmpty);
      expect(data.snapshot.value('weapon.cooldown', 0), isA<int>());
      expect(data.snapshot.value('player.terranSupplyMax', 0), isNull);
      expect(result.stdout, contains('"sha256"'));
      expect(data.build, greaterThan(0));
    },
    skip: path == null || helper == null
        ? 'Set STARCRAFT_TEST_INSTALLATION and STARCRAFT_DATA_HELPER_PATH.'
        : false,
  );
}
