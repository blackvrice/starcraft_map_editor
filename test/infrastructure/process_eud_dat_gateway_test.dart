import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_eud_dat_gateway.dart';

void main() {
  ProcessEudDatGateway gateway({
    Duration timeout = const Duration(seconds: 15),
    int limit = 2 * 1024 * 1024,
  }) => ProcessEudDatGateway(
    helperExecutablePath:
        '${Platform.environment['SystemRoot']}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    helperArguments: [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      File('test/fixtures/helpers/fake_eud_dat_helper.ps1').absolute.path,
    ],
    environment: Platform.environment,
    timeout: timeout,
    maximumOutputBytes: limit,
  );
  test('reads all columns and captures bounded provenance/logs', () async {
    final r = await gateway().read(
      operationId: 'test',
      installationPath: r'C:\fixture',
    );
    expect(r.isSuccess, isTrue, reason: '${r.errorCode}\n${r.stderr}');
    expect(r.source!.snapshot.value('weapon.cooldown', 0), 15);
    expect(r.stdout, contains('"sha256"'));
    expect(r.stderr, contains('synthetic EUD log'));
  });
  test(
    'rejects invalid response, process failure, output limit and invalid requests',
    () async {
      expect(
        (await gateway().read(
          operationId: 'test',
          installationPath: r'C:\invalid',
        )).errorCode,
        'SC_EUD_DAT_RESPONSE_INVALID',
      );
      final failed = await gateway().read(
        operationId: 'test',
        installationPath: r'C:\failure',
      );
      expect(failed.errorCode, 'SC_EUD_DAT_HELPER_FAILED');
      expect(failed.stderr, contains('SC_EUD_DAT_MISSING'));
      expect(
        (await gateway(
          limit: 10,
        ).read(operationId: 'test', installationPath: r'C:\fixture')).errorCode,
        'SC_EUD_DAT_OUTPUT_LIMIT',
      );
      expect(
        (await gateway().read(
          operationId: '../bad',
          installationPath: 'relative',
        )).errorCode,
        'SC_EUD_DAT_REQUEST_INVALID',
      );
    },
  );
  test(
    'times out, cancels pending startup and rejects duplicate operation IDs',
    () async {
      expect(
        (await gateway(
          timeout: const Duration(milliseconds: 50),
        ).read(operationId: 'test', installationPath: r'C:\hang')).errorCode,
        'SC_EUD_DAT_TIMED_OUT',
      );
      final g = gateway(),
          pending = g.read(operationId: 'test', installationPath: r'C:\hang');
      expect(
        (await g.read(
          operationId: 'test',
          installationPath: r'C:\fixture',
        )).errorCode,
        'SC_EUD_DAT_OPERATION_ACTIVE',
      );
      g.cancel('test');
      expect((await pending).errorCode, 'SC_EUD_DAT_CANCELLED');
    },
  );
}
