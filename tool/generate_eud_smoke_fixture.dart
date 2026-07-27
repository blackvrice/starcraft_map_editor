import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const _mapWidth = 32;
const _mapHeight = 32;
const _helperVersion = '0.4.0';
const _stormLibRevision = 'c91595a1a1b7b515567bd62a60af066914a29a6a';

Future<void> main(List<String> arguments) async {
  final options = _GeneratorOptions.parse(arguments);
  final repositoryRoot = File.fromUri(Platform.script).absolute.parent.parent;
  final templateMap = File(
    '${repositoryRoot.path}${Platform.pathSeparator}'
    'test${Platform.pathSeparator}fixtures${Platform.pathSeparator}'
    'maps${Platform.pathSeparator}generated${Platform.pathSeparator}'
    'minimal-self-authored.scx',
  );
  final helper = File(options.helperPath).absolute;
  final output = File(options.outputPath).absolute;

  if (!await helper.exists()) {
    throw StateError('Archive helper not found: ${helper.path}');
  }
  if (!await templateMap.exists()) {
    throw StateError('Template map not found: ${templateMap.path}');
  }
  if (await output.exists()) {
    throw StateError('Refusing to overwrite fixture: ${output.path}');
  }

  await output.parent.create(recursive: true);
  final scratch = await output.parent.createTemp('.eud-smoke-fixture-');
  try {
    final scenario = File(
      '${scratch.path}${Platform.pathSeparator}scenario.chk',
    );
    final generatedMap = File(
      '${scratch.path}${Platform.pathSeparator}eud-smoke-self-authored.scx',
    );
    final scenarioBytes = buildEudSmokeScenarioBytes();
    await scenario.writeAsBytes(scenarioBytes, flush: true);

    final request = jsonEncode({
      'protocolVersion': 1,
      'requestId': 'generate-eud-smoke-fixture',
      'operation': 'replaceScenario',
      'sourcePath': templateMap.path,
      'scenarioInputPath': scenario.path,
      'archiveOutputPath': generatedMap.path,
    });
    final process = await Process.start(
      helper.path,
      const [],
      workingDirectory: scratch.path,
      runInShell: false,
    );
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    process.stdin.writeln(request);
    await process.stdin.close();
    final exitCode = await process.exitCode;
    final stdoutText = await stdoutFuture;
    final stderrText = await stderrFuture;
    if (exitCode != 0 || !await generatedMap.exists()) {
      throw StateError(
        'Archive helper failed with exit code $exitCode.\n'
        'stdout: $stdoutText\n'
        'stderr: $stderrText',
      );
    }
    final response = jsonDecode(stdoutText.trim());
    if (response is! Map<String, Object?> ||
        response['protocolVersion'] != 1 ||
        response['requestId'] != 'generate-eud-smoke-fixture' ||
        response['operation'] != 'replaceScenario' ||
        response['helperVersion'] != _helperVersion ||
        response['stormLibRevision'] != _stormLibRevision ||
        response['status'] != 'success') {
      throw StateError('Archive helper returned an unexpected response.');
    }
    final outputMetadata = response['output'];
    final generatedMapSize = await generatedMap.length();
    if (outputMetadata is! Map<String, Object?> ||
        outputMetadata['archiveSizeBytes'] != generatedMapSize ||
        outputMetadata['scenarioSizeBytes'] != scenarioBytes.length) {
      throw StateError('Archive helper output metadata does not match.');
    }

    await generatedMap.rename(output.path);
    final archiveBytes = await output.readAsBytes();
    stdout.writeln('Created ${output.path}');
    stdout.writeln(
      'scenario.sha256=${sha256.convert(scenarioBytes)} '
      'scenario.size=${scenarioBytes.length}',
    );
    stdout.writeln(
      'archive.sha256=${sha256.convert(archiveBytes)} '
      'archive.size=${archiveBytes.length}',
    );
  } finally {
    if (await scratch.exists()) {
      await scratch.delete(recursive: true);
    }
  }
}

Uint8List buildEudSmokeScenarioBytes() {
  final output = BytesBuilder(copy: false);

  void addSection(String name, List<int> payload) {
    if (name.length != 4) {
      throw ArgumentError.value(name, 'name', 'CHK section names are 4 bytes');
    }
    output
      ..add(ascii.encode(name))
      ..add(_uint32(payload.length))
      ..add(payload);
  }

  addSection('TYPE', ascii.encode('RAWB'));
  addSection('VER ', _uint16(205));
  addSection('IVER', _uint16(10));
  addSection('VCOD', List<int>.filled(1040, 0));
  addSection('OWNR', [6, ...List<int>.filled(10, 0), 7]);
  addSection('ERA ', _uint16(0));
  addSection('DIM ', [..._uint16(_mapWidth), ..._uint16(_mapHeight)]);
  addSection('SIDE', [1, ...List<int>.filled(11, 0)]);
  addSection(
    'MTXM',
    List<int>.generate(
      _mapWidth * _mapHeight * 2,
      (index) => index.isEven ? 1 : 0,
      growable: false,
    ),
  );
  addSection('UNIT', const []);
  addSection('THG2', const []);
  addSection('MASK', List<int>.filled(_mapWidth * _mapHeight, 0xFF));
  addSection(
    'STR ',
    _legacyStringTable(const [
      'StarCraft Map Editor EUD Smoke',
      'Self-authored map for the real euddraft build smoke test.',
    ]),
  );
  addSection('MRGN', List<int>.filled(255 * 20, 0));
  addSection('SPRP', [..._uint16(1), ..._uint16(2)]);
  addSection('FORC', List<int>.filled(20, 0));
  addSection('COLR', List<int>.generate(8, (index) => index));
  addSection('PUNI', List<int>.filled(5700, 0));
  addSection('PUPx', List<int>.filled(2318, 0));
  addSection('PTEx', List<int>.filled(1672, 0));
  addSection('UNIx', List<int>.filled(4168, 0));
  addSection('UPGx', List<int>.filled(794, 0));
  addSection('TECx', List<int>.filled(396, 0));
  addSection('TRIG', const []);
  addSection('MBRF', const []);
  addSection('UPRP', List<int>.filled(64 * 20, 0));
  addSection('UPUS', List<int>.filled(64, 0));
  addSection('SWNM', List<int>.filled(256 * 4, 0));

  return output.takeBytes();
}

List<int> _legacyStringTable(List<String> strings) {
  final encoded = strings.map(ascii.encode).toList(growable: false);
  final headerSize = 2 + encoded.length * 2;
  var offset = headerSize;
  final output = <int>[..._uint16(encoded.length)];
  for (final string in encoded) {
    output.addAll(_uint16(offset));
    offset += string.length + 1;
  }
  for (final string in encoded) {
    output
      ..addAll(string)
      ..add(0);
  }
  return output;
}

List<int> _uint16(int value) {
  final data = ByteData(2)..setUint16(0, value, Endian.little);
  return data.buffer.asUint8List();
}

List<int> _uint32(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.little);
  return data.buffer.asUint8List();
}

final class _GeneratorOptions {
  const _GeneratorOptions({required this.helperPath, required this.outputPath});

  final String helperPath;
  final String outputPath;

  static _GeneratorOptions parse(List<String> arguments) {
    String? helperPath;
    String? outputPath;
    for (var index = 0; index < arguments.length; index += 2) {
      if (index + 1 >= arguments.length) {
        throw const FormatException(
          'Usage: --helper <map_archive_helper.exe> --output <fixture.scx>',
        );
      }
      switch (arguments[index]) {
        case '--helper':
          helperPath = arguments[index + 1];
        case '--output':
          outputPath = arguments[index + 1];
        default:
          throw FormatException('Unknown option: ${arguments[index]}');
      }
    }
    if (helperPath == null || outputPath == null) {
      throw const FormatException(
        'Usage: --helper <map_archive_helper.exe> --output <fixture.scx>',
      );
    }
    return _GeneratorOptions(helperPath: helperPath, outputPath: outputPath);
  }
}
