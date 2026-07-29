import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/infrastructure/assets/local_starcraft_data_asset_inspector.dart';

void main() {
  final inspector = LocalStarCraftDataAssetInspector();
  late Directory temporaryRoot;

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp(
      'starcraft_asset_inspector_',
    );
  });

  tearDown(() async {
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  test('accepts a complete nonempty loose tileset asset root', () async {
    final tilesetDirectory = await _writeCompleteAssetSet(temporaryRoot);

    final fromRoot = await inspector.inspect(temporaryRoot.path);
    final fromTilesetDirectory = await inspector.inspect(tilesetDirectory.path);

    for (final result in [fromRoot, fromTilesetDirectory]) {
      expect(result.isReady, isTrue);
      expect(result.requiredAssetCount, 40);
      expect(result.foundAssetCount, 40);
      expect(result.missingRelativePaths, isEmpty);
      expect(result.invalidRelativePaths, isEmpty);
      expect(result.diagnostics, isEmpty);
      expect(result.resolvedTilesetDirectoryPath, tilesetDirectory.path);
    }
  });

  test(
    'reports missing and empty files without reading their contents',
    () async {
      final tilesetDirectory = await _writeCompleteAssetSet(temporaryRoot);
      await File(
        '${tilesetDirectory.path}${Platform.pathSeparator}badlands.cv5',
      ).delete();
      await File(
        '${tilesetDirectory.path}${Platform.pathSeparator}platform.vf4',
      ).writeAsBytes(const []);

      final result = await inspector.inspect(temporaryRoot.path);

      expect(result.isReady, isFalse);
      expect(result.foundAssetCount, 38);
      expect(result.missingRelativePaths, [r'tileset\badlands.cv5']);
      expect(result.invalidRelativePaths, [r'tileset\platform.vf4']);
      expect(result.diagnostics.map((diagnostic) => diagnostic.code), [
        StarCraftDataAssetDiagnosticCodes.filesMissing,
        StarCraftDataAssetDiagnosticCodes.filesInvalid,
      ]);
      expect(
        result.diagnostics.first.rawDetails,
        contains(r'tileset\badlands.cv5'),
      );
    },
  );

  test(
    'diagnoses unsafe, absent, non-directory, and incomplete roots',
    () async {
      final invalidPath = await inspector.inspect('relative/assets');
      expect(
        invalidPath.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.rootPathInvalid,
      );

      final missingPath = await inspector.inspect(
        '${temporaryRoot.path}${Platform.pathSeparator}missing',
      );
      expect(
        missingPath.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.rootNotFound,
      );

      final file = File(
        '${temporaryRoot.path}${Platform.pathSeparator}assets.txt',
      );
      await file.writeAsString('not a directory');
      final filePath = await inspector.inspect(file.path);
      expect(
        filePath.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.rootNotDirectory,
      );

      final incompleteRoot = await inspector.inspect(temporaryRoot.path);
      expect(
        incompleteRoot.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.tilesetDirectoryMissing,
      );
      expect(incompleteRoot.missingRelativePaths, hasLength(40));
    },
  );
}

Future<Directory> _writeCompleteAssetSet(Directory root) async {
  final tilesetDirectory = Directory(
    '${root.path}${Platform.pathSeparator}tileset',
  );
  await tilesetDirectory.create();
  for (final requirement in StarCraftDataAssetManifest.requiredTilesetAssets) {
    await File(
      '${tilesetDirectory.path}${Platform.pathSeparator}'
      '${requirement.fileName}',
    ).writeAsBytes([requirement.tileset.rawValue + 1]);
  }
  return tilesetDirectory;
}
