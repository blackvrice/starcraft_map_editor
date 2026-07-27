import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_eud_smoke_fixture.dart';

void main() {
  test('generated SCX fixture matches its provenance manifest', () async {
    final manifestFile = File('test/fixtures/maps/generated/manifest.json');
    final decoded = jsonDecode(await manifestFile.readAsString());

    expect(decoded, isA<Map<String, Object?>>());
    final manifest = decoded as Map<String, Object?>;
    expect(manifest['schemaVersion'], 1);
    expect(
      manifest['provenance'],
      'Generated entirely from project-authored bytes',
    );
    expect(manifest['license'], 'MIT');

    final archive = manifest['archive']! as Map<String, Object?>;
    final archiveFile = File(
      'test/fixtures/maps/generated/${manifest['file']}',
    );
    final archiveBytes = await archiveFile.readAsBytes();
    expect(archiveBytes.length, archive['sizeBytes']);
    expect(sha256.convert(archiveBytes).toString(), archive['sha256']);
    expect(archive['formatVersion'], 1);
    expect(archive['totalEntryCount'], 3);
    expect(archive['entries'], [
      r'staredit\scenario.chk',
      r'staredit\units.dat',
      '(listfile)',
    ]);

    final scenario = manifest['scenario']! as Map<String, Object?>;
    final scenarioBytes = _loadHexFixture(scenario['source']! as String);
    expect(scenarioBytes.length, scenario['sizeBytes']);
    expect(sha256.convert(scenarioBytes).toString(), scenario['sha256']);
  });

  test('euddraft smoke fixture matches its provenance manifest', () async {
    final manifestFile = File('test/fixtures/maps/eud_smoke/manifest.json');
    final decoded = jsonDecode(await manifestFile.readAsString());

    expect(decoded, isA<Map<String, Object?>>());
    final manifest = decoded as Map<String, Object?>;
    expect(manifest['schemaVersion'], 1);
    expect(
      manifest['provenance'],
      'Generated entirely from project-authored bytes',
    );
    expect(manifest['license'], 'MIT');

    final archive = manifest['archive']! as Map<String, Object?>;
    final archiveFile = File(
      'test/fixtures/maps/eud_smoke/${manifest['file']}',
    );
    final archiveBytes = await archiveFile.readAsBytes();
    expect(archiveBytes.length, archive['sizeBytes']);
    expect(sha256.convert(archiveBytes).toString(), archive['sha256']);
    expect(archive['formatVersion'], 1);
    expect(archive['totalEntryCount'], 3);
    expect(archive['entries'], [
      r'staredit\scenario.chk',
      r'staredit\units.dat',
      '(listfile)',
    ]);

    final scenario = manifest['scenario']! as Map<String, Object?>;
    final scenarioBytes = buildEudSmokeScenarioBytes();
    expect(scenarioBytes.length, scenario['sizeBytes']);
    expect(sha256.convert(scenarioBytes).toString(), scenario['sha256']);
    expect(scenario['width'], 32);
    expect(scenario['height'], 32);
  });
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
