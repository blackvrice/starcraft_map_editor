Map<String, dynamic> terrainPlacementJson({int tileset = 0}) {
  const names = [
    'badlands',
    'platform',
    'install',
    'ashworld',
    'jungle',
    'desert',
    'ice',
    'twilight',
  ];
  return {
    'protocolVersion': 3,
    'helperVersion': '0.13.0',
    'cascLibRevision': '4971d363e665551ac4142f541e5f2d71f1cda653',
    'requestId': 'fixture',
    'operation': 'readTerrainPlacement',
    'status': 'success',
    'snapshotVersion': 1,
    'tileset': tileset,
    'installation': {
      'path': r'C:\StarCraft',
      'storageProduct': 's1',
      'storageBuildNumber': 13515,
    },
    'assets': [
      {
        'path': 'tileset\\${names[tileset]}.cv5',
        'bytes': 104,
        'sha256': 'a' * 64,
      },
      {
        'path': 'tileset\\${names[tileset]}.vf4',
        'bytes': 64,
        'sha256': 'b' * 64,
      },
    ],
    'groupBuildable': <dynamic>[true, false],
    'megaTileReferences': [
      List<dynamic>.filled(16, 0, growable: true),
      List<dynamic>.filled(16, 1, growable: true),
    ],
    'walkableMasks': <dynamic>[65535, 1],
  };
}
