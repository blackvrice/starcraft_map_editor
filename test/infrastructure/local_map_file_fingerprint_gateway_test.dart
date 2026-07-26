import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';

void main() {
  group('LocalMapFileFingerprintGateway', () {
    test('captures size, UTC modified time, and SHA-256', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'starcraft-map-editor-fingerprint-',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final file = File(
        '${tempDirectory.path}${Platform.pathSeparator}map.scx',
      );
      await file.writeAsString('abc', flush: true);
      await file.setLastModified(DateTime.utc(2026, 7, 26, 12));

      final fingerprint = await LocalMapFileFingerprintGateway().fingerprint(
        file.path,
      );

      expect(fingerprint.sizeBytes, 3);
      expect(fingerprint.modifiedAtUtc.isUtc, isTrue);
      expect(fingerprint.modifiedAtUtc, (await file.stat()).modified.toUtc());
      expect(
        fingerprint.sha256Digest,
        'ba7816bf8f01cfea414140de5dae2223'
        'b00361a396177a9cb410ff61f20015ad',
      );
    });

    test(
      'detects changed content even with the same size and modified time',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'starcraft-map-editor-fingerprint-',
        );
        addTearDown(() => tempDirectory.delete(recursive: true));
        final file = File(
          '${tempDirectory.path}${Platform.pathSeparator}map.scx',
        );
        await file.writeAsString('abc', flush: true);
        await file.setLastModified(DateTime.utc(2026, 7, 26, 12));
        final gateway = LocalMapFileFingerprintGateway();
        final before = await gateway.fingerprint(file.path);

        await file.writeAsString('abd', flush: true);
        await file.setLastModified(before.modifiedAtUtc);
        final after = await gateway.fingerprint(file.path);

        expect(after.sizeBytes, before.sizeBytes);
        expect(after.modifiedAtUtc, before.modifiedAtUtc);
        expect(after.sha256Digest, isNot(before.sha256Digest));
        expect(after, isNot(before));
      },
    );

    test('rejects a missing file', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'starcraft-map-editor-fingerprint-',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final missingPath =
          '${tempDirectory.path}${Platform.pathSeparator}missing.scx';

      expect(
        () => LocalMapFileFingerprintGateway().fingerprint(missingPath),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
