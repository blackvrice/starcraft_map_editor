import 'dart:typed_data';
import '../assets/map_sound.dart';
import 'chk_basic_editing.dart';
import 'chk_editing_clipboard.dart';
import 'raw_chk_document.dart';
import 'raw_chk_section.dart';
import 'typed/chk_resource_editor.dart';
import 'typed/chk_trigger_editor.dart';
import 'typed/chk_trigger_portability.dart';
import 'typed/chk_trigger_resources.dart';

/// A closed, immutable set of ordinary records. Never executes source code.
final class ChkDocumentTransfer {
  ChkDocumentTransfer._(
    this.source,
    this.objects,
    this.triggers,
    this.briefings,
    this.stringIds,
    this.locationIndices,
    this.switchIds,
    this.propertyIds,
    this.sounds,
  );
  final RawChkDocument source;
  final ChkEditingClipboard? objects;
  final List<ChkTrigger> triggers, briefings;
  final Set<int> stringIds, locationIndices, switchIds, propertyIds;
  final Map<int, String> sounds;
  static const _editor = ChkBasicEditing();
  static const maximumRecords = 4096;

  static int _tileset(RawChkDocument doc) {
    _editor.dimensions(doc);
    final era = _editor.section(doc, 'ERA ');
    if (era == null ||
        era.payload.length != 2 ||
        era.payload[1] != 0 ||
        era.payload[0] > 7) {
      throw StateError('TRANSFER_TILESET');
    }
    return era.payload[0];
  }

  /// Reject unused/reserved bytes as well as unknown opcodes and EUDX slots.
  /// The ordinary GUI's permissive in-place edits are not an import contract.
  static void _portable(ChkTrigger record, RawChkDocument doc) =>
      ChkTriggerPortability.requireCanonical(
        record,
        doc,
        diagnosticPrefix: 'TRANSFER',
      );

  static Iterable<(bool, int, TriggerOpcode, List<int>)> _slots(
    ChkTrigger record,
  ) sync* {
    for (final action in record.briefing ? [true] : [false, true]) {
      for (var i = 0; i < (action ? 64 : 16); i++) {
        final slot = record.slot(action, i);
        if (slot.every((b) => b == 0)) continue;
        yield (
          action,
          i,
          TriggerOpcodes.find(
            action,
            ChkTrigger.type(action, slot),
            briefing: record.briefing,
          )!,
          slot,
        );
      }
    }
  }

  static ChkDocumentTransfer capture(
    RawChkDocument source, {
    Map<String, Set<int>> selected = const {},
    Set<int> triggers = const {},
    Set<int> briefings = const {},
  }) {
    _tileset(source);
    if (selected.keys.any((k) => !{'UNIT', 'THG2', 'MRGN'}.contains(k))) {
      throw StateError('TRANSFER_OBJECT_KIND');
    }
    final strings = <int>{},
        locations = {...?selected['MRGN']},
        switches = <int>{},
        properties = <int>{},
        sounds = <int, String>{};
    List<ChkTrigger> pick(Set<int> indices, bool briefing) {
      if (indices.isEmpty) return const [];
      final all = ChkTriggers.read(source, briefing: briefing).records;
      return [
        for (final i in indices.toList()..sort())
          all[RangeError.checkValidIndex(i, all)],
      ];
    }

    final tr = pick(triggers, false), br = pick(briefings, true);
    final count =
        selected.values.fold(0, (n, v) => n + v.length) + tr.length + br.length;
    if (count == 0 || count > maximumRecords) {
      throw StateError('TRANSFER_RECORD_LIMIT');
    }
    for (final record in [...tr, ...br]) {
      _portable(record, source);
      for (final (_, _, op, slot) in _slots(record)) {
        for (final a in op.arguments) {
          final id = ChkTrigger.argument(slot, a);
          switch (a.reference) {
            case 'location':
              if (id != 64) locations.add(id - 1);
            case 'string':
              strings.add(id);
              if (a.offset == 8) {
                final raw = ChkResourceEditor.table(
                  source,
                ).entryForId(id)!.rawBytes!;
                if (raw.any((b) => b > 127)) {
                  throw StateError('TRANSFER_SOUND_PATH');
                }
                sounds[id] = MapSound.path(String.fromCharCodes(raw));
              }
            case 'switch':
              switches.add(id);
            case 'property':
              properties.add(id);
          }
        }
      }
    }
    final names = _editor.section(source, 'MRGN', stride: 20)?.payload;
    for (final index in locations) {
      if (names == null ||
          index < 0 ||
          index >= names.length ~/ 20 ||
          index == 63) {
        throw StateError('TRANSFER_LOCATION');
      }
      final name = ByteData.sublistView(
        names,
      ).getUint16(index * 20 + 16, Endian.little);
      if (name != 0) strings.add(name);
    }
    final sw = ChkTriggerResources.index(source, 'SWNM', 1024);
    for (final id in switches) {
      if (sw != null) {
        final name = ByteData.sublistView(
          source.sections[sw].payload,
        ).getUint32(id * 4, Endian.little);
        if (name != 0) strings.add(name);
      }
    }
    final chosen = {
      for (final e in selected.entries) e.key: {...e.value},
    };
    if (locations.isNotEmpty) chosen['MRGN'] = locations;
    final clip = chosen.values.any((s) => s.isNotEmpty)
        ? ChkEditingClipboard.capture(source, {
            for (final e in chosen.entries)
              if (e.value.isNotEmpty) e.key: e.value,
          })
        : null;
    if ((clip?.records.values.fold(0, (n, v) => n + v.length) ?? 0) +
            tr.length +
            br.length >
        maximumRecords) {
      throw StateError('TRANSFER_RECORD_LIMIT');
    }
    for (final id in strings) {
      if (ChkResourceEditor.table(source).entryForId(id)?.isStructurallyValid !=
          true) {
        throw StateError('TRANSFER_STRING');
      }
    }
    return ChkDocumentTransfer._(
      source,
      clip,
      List.unmodifiable(tr),
      List.unmodifiable(br),
      Set.unmodifiable(strings),
      Set.unmodifiable(locations),
      Set.unmodifiable(switches),
      Set.unmodifiable(properties),
      Map.unmodifiable(sounds),
    );
  }

  ChkDocumentTransferPlan preview(
    RawChkDocument target, {
    int offsetX = 0,
    int offsetY = 0,
    Map<int, int> owners = const {},
  }) {
    if (_tileset(target) != _tileset(source)) {
      throw StateError('TRANSFER_TILESET');
    }
    final players = {for (var p = 0; p < 12; p++) p: owners[p] ?? p};
    if (owners.keys.any((p) => p < 0 || p > 11) ||
        players.values.any((p) => p < 0 || p > 11) ||
        players.values.toSet().length != 12) {
      throw StateError('TRANSFER_OWNER_MAPPING');
    }
    if ([...triggers, ...briefings].any(
      (r) => _slots(r).any(
        (s) => s.$3.arguments.any(
          (a) =>
              a.reference == 'location' && ChkTrigger.argument(s.$4, a) == 64,
        ),
      ),
    )) {
      int? elevation;
      for (final doc in [source, target]) {
        final (w, h) = _editor.dimensions(doc);
        final bytes = _editor.section(doc, 'MRGN', stride: 20)?.payload;
        if (bytes == null || bytes.length < 1280) {
          throw StateError('TRANSFER_ANYWHERE');
        }
        final data = ByteData.sublistView(bytes), at = 63 * 20;
        final mask = data.getUint16(at + 18, Endian.little);
        if (data.getUint32(at, Endian.little) != 0 ||
            data.getUint32(at + 4, Endian.little) != 0 ||
            data.getUint32(at + 8, Endian.little) != w * 32 ||
            data.getUint32(at + 12, Endian.little) != h * 32 ||
            (elevation != null && elevation != mask)) {
          throw StateError('TRANSFER_ANYWHERE');
        }
        elevation = mask;
      }
    }
    var result = target;
    final stringMap = <int, int>{},
        locationMap = <int, int>{64: 64},
        switchMap = <int, int>{},
        propertyMap = <int, int>{};
    // Blank location bytes do not imply an unused ID: existing triggers may
    // already refer to that slot. Opaque users make allocation unsafe.
    final usedLocations = <int>{64},
        usedSwitches = <int>{},
        usedProperties = <int>{};
    if (locationIndices.isNotEmpty ||
        switchIds.isNotEmpty ||
        propertyIds.isNotEmpty) {
      for (final r in ChkTriggers.read(target).records) {
        _portable(r, target);
        for (final (_, _, op, slot) in _slots(r)) {
          for (final a in op.arguments) {
            final id = ChkTrigger.argument(slot, a);
            if (a.reference == 'location') usedLocations.add(id);
            if (a.reference == 'switch') usedSwitches.add(id);
            if (a.reference == 'property') usedProperties.add(id);
          }
        }
      }
    }
    if (stringIds.isNotEmpty) {
      final sourceTable = ChkResourceEditor.table(source);
      final ids = stringIds.toList()..sort();
      final table = ChkResourceEditor.table(result);
      final added = table.withAddedRawStrings(
        rawStrings: [
          for (final id in ids) sourceTable.entryForId(id)!.rawBytes!,
        ],
      );
      result = result.replaceSection(table.sectionIndex, added.section);
      for (var i = 0; i < ids.length; i++) {
        stringMap[ids[i]] = added.stringIds[i];
      }
    }
    if (locationIndices.isNotEmpty) {
      final bytes = _editor.section(result, 'MRGN', stride: 20)?.payload;
      if (bytes == null || !{1280, 5100}.contains(bytes.length)) {
        throw StateError('TRANSFER_LOCATION');
      }
      final free = [
        for (var i = 0; i < bytes.length ~/ 20; i++)
          if (!usedLocations.contains(i + 1) &&
              bytes.sublist(i * 20, i * 20 + 20).every((b) => b == 0))
            i,
      ];
      if (free.length < locationIndices.length) {
        throw StateError('TRANSFER_LOCATION_LIMIT');
      }
      final indices = locationIndices.toList()..sort();
      for (var i = 0; i < indices.length; i++) {
        locationMap[indices[i] + 1] = free[i] + 1;
      }
    }
    if (switchIds.isNotEmpty) {
      final index = ChkTriggerResources.index(result, 'SWNM', 1024);
      final bytes = index == null
          ? Uint8List(1024)
          : result.sections[index].payload;
      final data = ByteData.sublistView(bytes);
      final sourceSw = ChkTriggerResources.index(source, 'SWNM', 1024);
      for (final id in switchIds.toList()..sort()) {
        final free = Iterable.generate(256)
            .where(
              (i) =>
                  !usedSwitches.contains(i) &&
                  data.getUint32(i * 4, Endian.little) == 0,
            )
            .firstOrNull;
        if (free == null) throw StateError('TRANSFER_SWITCH_LIMIT');
        usedSwitches.add(free);
        switchMap[id] = free;
        final name = sourceSw == null
            ? 0
            : ByteData.sublistView(
                source.sections[sourceSw].payload,
              ).getUint32(id * 4, Endian.little);
        data.setUint32(
          free * 4,
          name == 0 ? 0 : stringMap[name]!,
          Endian.little,
        );
      }
      result = _put(result, 'SWNM', bytes);
    }
    if (propertyIds.isNotEmpty) {
      final p = ChkTriggerResources.index(result, 'UPRP', 1280),
          u = ChkTriggerResources.index(result, 'UPUS', 64);
      final props = p == null ? Uint8List(1280) : result.sections[p].payload;
      final usage = u == null ? Uint8List(64) : result.sections[u].payload;
      for (final id in propertyIds.toList()..sort()) {
        final free = Iterable.generate(64)
            .where(
              (i) =>
                  usage[i] == 0 &&
                  !usedProperties.contains(i + 1) &&
                  props.sublist(i * 20, i * 20 + 20).every((b) => b == 0),
            )
            .firstOrNull;
        if (free == null) throw StateError('TRANSFER_PROPERTY_LIMIT');
        usedProperties.add(free + 1);
        propertyMap[id] = free + 1;
        props.setRange(
          free * 20,
          free * 20 + 20,
          ChkTriggerResources.property(source, id),
        );
        usage[free] = 1;
      }
      result = _put(_put(result, 'UPRP', props), 'UPUS', usage);
    }
    if (objects != null) {
      result = objects!.paste(
        result,
        x: objects!.anchorX + offsetX,
        y: objects!.anchorY + offsetY,
        locationStrings: stringMap,
        owners: players,
        reservedLocations: usedLocations,
      );
    }
    final unitIds = <int, int>{};
    final units = objects?.records['UNIT'] ?? const <List<int>>[];
    if (units.isNotEmpty) {
      final bytes = _editor.section(result, 'UNIT', stride: 36)!.payload;
      for (var i = 0; i < units.length; i++) {
        final oldId = ByteData.sublistView(
          Uint8List.fromList(units[i]),
        ).getUint32(0, Endian.little);
        if (oldId != 0) {
          unitIds[oldId] = ByteData.sublistView(
            bytes,
          ).getUint32(bytes.length - units.length * 36 + i * 36, Endian.little);
        }
      }
    }
    for (final briefing in [false, true]) {
      final copied = briefing ? briefings : triggers;
      if (copied.isEmpty) continue;
      final existing = ChkTriggers.read(result, briefing: briefing);
      final records = <ChkTrigger>[];
      for (final original in copied) {
        var next = original;
        for (final (action, i, op, slot) in _slots(original)) {
          final values = <String, int>{};
          for (final a in op.arguments) {
            final id = ChkTrigger.argument(slot, a);
            values[a.name] = switch (a.reference) {
              'location' => locationMap[id]!,
              'string' => stringMap[id]!,
              'switch' => switchMap[id]!,
              'property' => propertyMap[id]!,
              _ =>
                identical(a.choices, TriggerOpcodes.players) && id < 12
                    ? players[id]!
                    : id,
            };
          }
          next = next.withSlot(
            action,
            i,
            ChkTrigger.makeSlot(
              action,
              op,
              values,
              result,
              original: slot,
              briefing: briefing,
            ),
          );
        }
        final bytes = Uint8List.fromList(next.bytes);
        for (var p = 0; p < 12; p++) {
          bytes[2372 + players[p]!] = next.bytes[2372 + p];
        }
        records.add(ChkTrigger(bytes, briefing: briefing));
      }
      result = _put(
        result,
        briefing ? 'MBRF' : 'TRIG',
        ChkTriggers.encode([...existing.records, ...records]),
      );
    }
    if (sounds.isNotEmpty) {
      final at = ChkTriggerResources.index(result, 'WAV ', 2048);
      final bytes = at == null ? Uint8List(2048) : result.sections[at].payload;
      final data = ByteData.sublistView(bytes);
      for (final id in sounds.keys.toList()..sort()) {
        final free = Iterable.generate(
          512,
        ).where((i) => data.getUint32(i * 4, Endian.little) == 0).firstOrNull;
        if (free == null) throw StateError('TRANSFER_SOUND_LIMIT');
        data.setUint32(free * 4, stringMap[id]!, Endian.little);
      }
      result = _put(result, 'WAV ', bytes);
    }
    return ChkDocumentTransferPlan._(
      target,
      result,
      this,
      stringMap,
      locationMap,
      switchMap,
      propertyMap,
      unitIds,
      players,
    );
  }

  static RawChkDocument _put(RawChkDocument doc, String name, List<int> bytes) {
    final old = _editor.section(doc, name);
    return old == null
        ? doc.appendSection(
            RawChkSection(
              nameBytes: name.codeUnits,
              declaredLength: bytes.length,
              payload: bytes,
              sourceOffset: doc.sourceLength,
              isDirty: true,
            ),
          )
        : doc.replaceSection(doc.sections.indexOf(old), old.withPayload(bytes));
  }
}

final class ChkDocumentTransferPlan {
  ChkDocumentTransferPlan._(
    this.target,
    this.result,
    this.clipboard,
    Map<int, int> strings,
    Map<int, int> locations,
    Map<int, int> switches,
    Map<int, int> properties,
    Map<int, int> units,
    Map<int, int> owners,
  ) : strings = Map.unmodifiable(strings),
      locations = Map.unmodifiable(locations),
      switches = Map.unmodifiable(switches),
      properties = Map.unmodifiable(properties),
      units = Map.unmodifiable(units),
      owners = Map.unmodifiable(owners);
  final RawChkDocument target, result;
  final ChkDocumentTransfer clipboard;
  final Map<int, int> strings, locations, switches, properties, units, owners;
}
