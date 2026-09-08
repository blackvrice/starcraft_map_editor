import '../layers/map_layer_controller.dart';

/// Stable reasons a catalog placement is refused by the placement command.
///
/// Domain level reasons keep their `CHK_PLACEMENT_*` codes and are passed
/// through unchanged, so the UI can show one code per refusal without knowing
/// which layer produced it.
abstract final class ObjectPlacementDiagnosticCodes {
  static const sessionNotEditable = 'OBJECT_PLACEMENT_SESSION_NOT_EDITABLE';
  static const layerLocked = 'OBJECT_PLACEMENT_LAYER_LOCKED';
  static const outOfBounds = 'OBJECT_PLACEMENT_OUT_OF_BOUNDS';
  static const dimensionsUnavailable =
      'OBJECT_PLACEMENT_DIMENSIONS_UNAVAILABLE';
  static const sectionAmbiguous = 'OBJECT_PLACEMENT_SECTION_AMBIGUOUS';
  static const classIdExhausted = 'OBJECT_PLACEMENT_CLASS_ID_EXHAUSTED';
  static const terrainUnavailable = 'OBJECT_PLACEMENT_TERRAIN_UNAVAILABLE';
  static const tilesetUnavailable = 'OBJECT_PLACEMENT_TILESET_UNAVAILABLE';
  static const doodadTilesetMismatch =
      'OBJECT_PLACEMENT_DOODAD_TILESET_MISMATCH';
  static const doodadTerrainMismatch =
      'OBJECT_PLACEMENT_DOODAD_TERRAIN_MISMATCH';

  static const all = <String>{
    sessionNotEditable,
    layerLocked,
    outOfBounds,
    dimensionsUnavailable,
    sectionAmbiguous,
    classIdExhausted,
    terrainUnavailable,
    tilesetUnavailable,
    doodadTilesetMismatch,
    doodadTerrainMismatch,
  };
}

/// The outcome of one catalog placement.
///
/// A refused placement changes nothing: no section is added or replaced, the
/// document stays clean and no Undo entry is recorded.
final class ObjectPlacementResult {
  const ObjectPlacementResult._({this.placedObject, this.issueCode});

  factory ObjectPlacementResult.placed(MapLayerObjectRef object) =>
      ObjectPlacementResult._(placedObject: object);

  factory ObjectPlacementResult.refused(String issueCode) =>
      ObjectPlacementResult._(issueCode: issueCode);

  final MapLayerObjectRef? placedObject;
  final String? issueCode;

  bool get isPlaced => placedObject != null;
}
