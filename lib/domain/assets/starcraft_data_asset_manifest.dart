enum StarCraftTilesetAssetSet {
  badlands(rawValue: 0, fileStem: 'badlands', displayName: 'Badlands'),
  spacePlatform(
    rawValue: 1,
    fileStem: 'platform',
    displayName: 'Space Platform',
  ),
  installation(rawValue: 2, fileStem: 'install', displayName: 'Installation'),
  ashworld(rawValue: 3, fileStem: 'ashworld', displayName: 'Ashworld'),
  jungle(rawValue: 4, fileStem: 'jungle', displayName: 'Jungle'),
  desert(rawValue: 5, fileStem: 'desert', displayName: 'Desert'),
  ice(rawValue: 6, fileStem: 'ice', displayName: 'Ice'),
  twilight(rawValue: 7, fileStem: 'twilight', displayName: 'Twilight');

  const StarCraftTilesetAssetSet({
    required this.rawValue,
    required this.fileStem,
    required this.displayName,
  });

  final int rawValue;
  final String fileStem;
  final String displayName;
}

enum StarCraftTilesetAssetKind {
  groups(extension: 'cv5', displayName: 'Groups'),
  flags(extension: 'vf4', displayName: 'Flags'),
  megatiles(extension: 'vx4ex', displayName: 'Extended megatiles'),
  minitiles(extension: 'vr4', displayName: 'Minitiles'),
  palette(extension: 'wpe', displayName: 'Palette');

  const StarCraftTilesetAssetKind({
    required this.extension,
    required this.displayName,
  });

  final String extension;
  final String displayName;
}

final class StarCraftDataAssetRequirement {
  const StarCraftDataAssetRequirement({
    required this.tileset,
    required this.kind,
  });

  final StarCraftTilesetAssetSet tileset;
  final StarCraftTilesetAssetKind kind;

  String get fileName => '${tileset.fileStem}.${kind.extension}';

  String get relativePath => 'tileset\\$fileName';
}

abstract final class StarCraftDataAssetManifest {
  static const List<StarCraftTilesetAssetKind> renderAssetKinds = [
    StarCraftTilesetAssetKind.groups,
    StarCraftTilesetAssetKind.megatiles,
    StarCraftTilesetAssetKind.minitiles,
    StarCraftTilesetAssetKind.palette,
  ];

  static final List<StarCraftDataAssetRequirement> requiredTilesetAssets =
      List.unmodifiable([
        for (final tileset in StarCraftTilesetAssetSet.values)
          for (final kind in StarCraftTilesetAssetKind.values)
            StarCraftDataAssetRequirement(tileset: tileset, kind: kind),
      ]);

  static List<StarCraftDataAssetRequirement> renderAssetsFor(
    StarCraftTilesetAssetSet tileset,
  ) {
    return List.unmodifiable([
      for (final kind in renderAssetKinds)
        StarCraftDataAssetRequirement(tileset: tileset, kind: kind),
    ]);
  }
}
