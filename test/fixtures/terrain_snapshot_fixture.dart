Map<String, dynamic> terrainSnapshotJson() => {
  'protocolVersion': 3,
  'helperVersion': '0.11.0',
  'cascLibRevision': '4971d363e665551ac4142f541e5f2d71f1cda653',
  'requestId': 'fixture',
  'operation': 'readTerrainConnections',
  'status': 'success',
  'snapshotVersion': 2,
  'tileset': 0,
  'isomShapesResolved': false,
  'installation': {
    'path': r'C:\StarCraft',
    'storageProduct': 's1',
    'storageBuildNumber': 13515,
  },
  'assets': [
    for (final (extension, size) in [
      ('cv5', 104),
      ('vx4ex', 64),
      ('vr4', 64),
      ('wpe', 1024),
    ])
      {
        'path': 'tileset\\badlands.$extension',
        'bytes': size,
        'sha256': 'a' * 64,
      },
  ],
  'groups': [
    for (var i = 0; i < 2; i++)
      {
        'group': i,
        'terrainTypeWord': 65535,
        'flagsWord': 32769,
        'linkWords': [0, 48, 64, 65535],
        'stackWords': [0, 1, 2, 3],
        'megaTileReferences': List<dynamic>.filled(16, 1),
        'renderableMembers': [0, 3, 15],
      },
  ],
};
