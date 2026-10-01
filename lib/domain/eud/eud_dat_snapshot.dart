import 'eud_dat_layout.dart';
import 'eud_field_manifest.dart';
import 'eud_project.dart';
import '../placement/unit_weapon_references.dart';

typedef EudDatNode = ({EudTable table, int id});

/// Immutable local defaults. These are not effective CHK or runtime values.
final class EudDatSnapshot {
  EudDatSnapshot(Map<String, List<int>> values)
    : columns = Map.unmodifiable({
        for (final entry in values.entries)
          entry.key: List<int>.unmodifiable(entry.value),
      }) {
    if (values.length != EudDatLayout.counts.length) {
      throw const FormatException('Incomplete DAT columns.');
    }
    for (final entry in EudDatLayout.counts.entries) {
      final column = columns[entry.key];
      if (column == null ||
          column.length != entry.value ||
          column.any(
            (v) =>
                v < 0 || v > (1 << (8 * EudDatLayout.widths[entry.key]!)) - 1,
          )) {
        throw FormatException('Invalid DAT column ${entry.key}.');
      }
    }
  }
  final Map<String, List<int>> columns;
  int? raw(String key, int id) {
    final values = columns[key];
    return values != null && id >= 0 && id < values.length ? values[id] : null;
  }

  Object? value(String key, int id) {
    final number = raw(key, id);
    if (number == null) return null;
    final value = EudDatLayout.value(key, number);
    return EudFieldManifest.validate(key, id, value) == null ? value : null;
  }

  UnitWeaponIndex weaponIndex([Iterable<EudOverride> overrides = const []]) {
    for (final o in overrides) {
      if (EudFieldManifest.validate(o.field, o.targetId, o.value) != null) {
        throw FormatException('Invalid override ${o.identity}.');
      }
    }
    final staged = {for (final o in overrides) o.identity: o};
    int get(String key, int id) =>
        staged['$key:$id']?.value as int? ?? raw(key, id)!;
    return UnitWeaponIndex([
      for (var id = 0; id < 228; id++)
        UnitWeaponReferences(
          ground: get('unit.groundWeapon', id),
          air: get('unit.airWeapon', id),
          subunit1: raw('unit.subunit1', id)!,
          subunit2: raw('unit.subunit2', id)!,
        ),
    ]);
  }

  EudDatGraph graph([Iterable<EudOverride> overrides = const []]) =>
      EudDatGraph(this, overrides);
}

/// DAT reachability only: excludes dynamic IScript overlays, orders, HD assets.
final class EudDatGraph {
  EudDatGraph(EudDatSnapshot snapshot, Iterable<EudOverride> overrides) {
    final patches = <String, EudOverride>{};
    for (final o in overrides) {
      if (EudFieldManifest.validate(o.field, o.targetId, o.value) != null) {
        throw FormatException('Invalid override ${o.identity}.');
      }
      if (patches.containsKey(o.identity)) {
        throw FormatException('Duplicate override ${o.identity}.');
      }
      patches[o.identity] = o;
    }
    const links = <String, ({EudTable to, int limit, int? none})>{
      'unit.groundWeapon': (to: EudTable.weapon, limit: 130, none: 130),
      'unit.airWeapon': (to: EudTable.weapon, limit: 130, none: 130),
      'unit.subunit1': (to: EudTable.unit, limit: 228, none: 228),
      'unit.subunit2': (to: EudTable.unit, limit: 228, none: 228),
      'unit.flingy': (to: EudTable.flingy, limit: 209, none: null),
      'weapon.flingy': (to: EudTable.flingy, limit: 209, none: null),
      'flingy.sprite': (to: EudTable.sprite, limit: 517, none: null),
      'sprite.image': (to: EudTable.image, limit: 999, none: null),
      'unit.construction_animation': (
        to: EudTable.image,
        limit: 999,
        none: null,
      ),
    };
    for (final link in links.entries) {
      final table = EudTable.values.byName(link.key.split('.').first);
      final values = snapshot.columns[link.key]!;
      for (var id = 0; id < values.length; id++) {
        final target = patches['${link.key}:$id']?.value as int? ?? values[id];
        if (target == link.value.none) continue;
        if (target >= link.value.limit) {
          _unresolved.add('${link.key}:$id → $target');
          continue;
        }
        final to = (table: link.value.to, id: target);
        (_reverse[to] ??= {}).add((table: table, id: id));
      }
    }
  }
  final _reverse = <EudDatNode, Set<EudDatNode>>{};
  final _unresolved = <String>[];
  List<String> get unresolved => List.unmodifiable(_unresolved);
  List<EudDatNode> directUsers(EudDatNode node) =>
      _ordered(_reverse[node] ?? {});
  List<EudDatNode> allUsers(EudDatNode node) {
    final visited = <EudDatNode>{node}, result = <EudDatNode>{};
    final pending = <EudDatNode>[node];
    for (var i = 0; i < pending.length; i++) {
      for (final user in _reverse[pending[i]] ?? <EudDatNode>{}) {
        if (visited.add(user)) {
          result.add(user);
          pending.add(user);
        }
      }
    }
    return _ordered(result);
  }

  static List<EudDatNode> _ordered(Iterable<EudDatNode> values) =>
      List.unmodifiable(
        values.toList()..sort((a, b) {
          final table = a.table.index.compareTo(b.table.index);
          return table == 0 ? a.id.compareTo(b.id) : table;
        }),
      );
}
