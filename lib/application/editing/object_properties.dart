import '../layers/map_layer_controller.dart';

abstract final class ObjectPropertyFields {
  static const typeId = 'typeId';
  static const x = 'x';
  static const y = 'y';
  static const owner = 'owner';
  static const hitpointPercent = 'hitpointPercent';
  static const shieldPercent = 'shieldPercent';
  static const energyPercent = 'energyPercent';
  static const resourceAmount = 'resourceAmount';
  static const hangarAmount = 'hangarAmount';
  static const enabledValue = 'enabledValue';
}

sealed class ObjectProperties {
  const ObjectProperties({required this.object});

  final MapLayerObjectRef object;
}

final class UnitObjectProperties extends ObjectProperties {
  const UnitObjectProperties({
    required super.object,
    required this.typeId,
    required this.x,
    required this.y,
    required this.owner,
    required this.hitpointPercent,
    required this.shieldPercent,
    required this.energyPercent,
    required this.resourceAmount,
    required this.hangarAmount,
    required this.classId,
    required this.relationFlags,
    required this.validStateFlags,
    required this.validFieldFlags,
    required this.stateFlags,
    required this.unused,
    required this.relationClassId,
  });

  final int typeId;
  final int x;
  final int y;
  final int owner;
  final int hitpointPercent;
  final int shieldPercent;
  final int energyPercent;
  final int resourceAmount;
  final int hangarAmount;
  final int classId;
  final int relationFlags;
  final int validStateFlags;
  final int validFieldFlags;
  final int stateFlags;
  final int unused;
  final int relationClassId;
}

final class DoodadObjectProperties extends ObjectProperties {
  const DoodadObjectProperties({
    required super.object,
    required this.typeId,
    required this.x,
    required this.y,
    required this.owner,
    required this.enabledValue,
  });

  final int typeId;
  final int x;
  final int y;
  final int owner;
  final int enabledValue;
}

final class SpriteObjectProperties extends ObjectProperties {
  const SpriteObjectProperties({
    required super.object,
    required this.typeId,
    required this.x,
    required this.y,
    required this.owner,
    required this.unused,
    required this.flags,
  });

  final int typeId;
  final int x;
  final int y;
  final int owner;
  final int unused;
  final int flags;
}

final class LocationObjectProperties extends ObjectProperties {
  const LocationObjectProperties({
    required super.object,
    required this.locationId,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.stringId,
    required this.elevationFlags,
  });

  final int locationId;
  final int left;
  final int top;
  final int right;
  final int bottom;
  final int stringId;
  final int elevationFlags;
}

sealed class ObjectPropertyUpdate {
  const ObjectPropertyUpdate({required this.object});

  final MapLayerObjectRef object;
}

final class UnitObjectPropertyUpdate extends ObjectPropertyUpdate {
  const UnitObjectPropertyUpdate({
    required super.object,
    required this.typeId,
    required this.x,
    required this.y,
    required this.owner,
    required this.hitpointPercent,
    required this.shieldPercent,
    required this.energyPercent,
    required this.resourceAmount,
    required this.hangarAmount,
  });

  final int typeId;
  final int x;
  final int y;
  final int owner;
  final int hitpointPercent;
  final int shieldPercent;
  final int energyPercent;
  final int resourceAmount;
  final int hangarAmount;
}

final class DoodadObjectPropertyUpdate extends ObjectPropertyUpdate {
  const DoodadObjectPropertyUpdate({
    required super.object,
    required this.typeId,
    required this.x,
    required this.y,
    required this.owner,
    required this.enabledValue,
  });

  final int typeId;
  final int x;
  final int y;
  final int owner;
  final int enabledValue;
}

final class SpriteObjectPropertyUpdate extends ObjectPropertyUpdate {
  const SpriteObjectPropertyUpdate({
    required super.object,
    required this.typeId,
    required this.x,
    required this.y,
    required this.owner,
  });

  final int typeId;
  final int x;
  final int y;
  final int owner;
}

enum ObjectPropertyEditStatus { applied, noChanges, invalid, unavailable }

final class ObjectPropertyEditResult {
  ObjectPropertyEditResult._(
    this.status, {
    Map<String, String> errors = const {},
  }) : errors = Map.unmodifiable(errors);

  factory ObjectPropertyEditResult.applied() =>
      ObjectPropertyEditResult._(ObjectPropertyEditStatus.applied);

  factory ObjectPropertyEditResult.noChanges() =>
      ObjectPropertyEditResult._(ObjectPropertyEditStatus.noChanges);

  factory ObjectPropertyEditResult.invalid(Map<String, String> errors) =>
      ObjectPropertyEditResult._(
        ObjectPropertyEditStatus.invalid,
        errors: errors,
      );

  factory ObjectPropertyEditResult.unavailable() =>
      ObjectPropertyEditResult._(ObjectPropertyEditStatus.unavailable);

  final ObjectPropertyEditStatus status;
  final Map<String, String> errors;

  bool get didApply => status == ObjectPropertyEditStatus.applied;
}
