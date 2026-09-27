import 'dart:convert';
import 'dart:typed_data';
import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_string_views.dart';
import 'chk_trigger_editor.dart';

class StringUse {
  const StringUse(
    this.section,
    this.offset,
    this.width,
    this.id,
    this.label, {
    this.sound = false,
    this.registration = false,
  });
  final int section, offset, width, id;
  final String label;
  final bool sound, registration;
}

class ResourceReferences {
  const ResourceReferences(this.uses, this.uncertainties);
  final List<StringUse> uses;
  final List<String> uncertainties;
}

abstract final class ChkResourceEditor {
  static ChkStringTableView table(
    RawChkDocument doc, {
    bool forEditing = true,
  }) {
    final views = const ChkStringViewDecoder().decode(doc);
    final tables = [...views.legacyTables, ...views.extendedTables];
    if (doc.sections
                .where((s) => s.name == 'STR ' || s.name == 'STRx')
                .length !=
            1 ||
        tables.length != 1 ||
        (forEditing && !tables.single.canAppendSafely)) {
      throw const FormatException(
        'One structurally safe STR/STRx table is required for editing.',
      );
    }
    return tables.single;
  }

  static ResourceReferences references(RawChkDocument doc) {
    final uses = <StringUse>[], unknown = <String>[];
    const opaqueSafe = {
      'TYPE',
      'VER ',
      'IVER',
      'IVE2',
      'VCOD',
      'OWNR',
      'ERA ',
      'DIM ',
      'SIDE',
      'MTXM',
      'PUNI',
      'UNIT',
      'ISOM',
      'TILE',
      'DD2 ',
      'THG2',
      'MASK',
      'UPRP',
      'UPUS',
      'UPGS',
      'UPGR',
      'TECS',
      'PTEC',
      'UPGx',
      'PUPx',
      'TECx',
      'PTEx',
      'COLR',
      'CRGB',
      'STR ',
      'STRx',
    };
    for (var s = 0; s < doc.sections.length; s++) {
      final section = doc.sections[s],
          bytes = Uint8List.fromList(doc.sections[s].payload);
      final data = ByteData.sublistView(bytes);
      void use(
        int offset,
        int width,
        String label, {
        bool sound = false,
        bool registration = false,
      }) {
        if (offset + width > bytes.length) {
          unknown.add('Truncated ${section.name}');
          return;
        }
        final id = width == 2
            ? data.getUint16(offset, Endian.little)
            : data.getUint32(offset, Endian.little);
        if (id != 0) {
          uses.add(
            StringUse(
              s,
              offset,
              width,
              id,
              '${section.name} $label',
              sound: sound,
              registration: registration,
            ),
          );
        }
      }

      switch (section.name) {
        case 'SPRP':
          if (bytes.length != 4) unknown.add('Malformed SPRP');
          use(0, 2, 'title');
          use(2, 2, 'description');
        case 'FORC':
          if (bytes.length != 20) unknown.add('Malformed FORC');
          for (var i = 0; i < 4; i++) {
            use(8 + i * 2, 2, 'force ${i + 1}');
          }
        case 'MRGN':
          if (bytes.length % 20 != 0) unknown.add('Malformed MRGN');
          for (var i = 0; i < bytes.length ~/ 20; i++) {
            use(i * 20 + 16, 2, 'location ${i + 1}');
          }
        case 'SWNM':
          if (bytes.length != 1024) unknown.add('Malformed SWNM');
          for (var i = 0; i < bytes.length ~/ 4; i++) {
            use(i * 4, 4, 'switch $i');
          }
        case 'WAV ':
          if (bytes.length != 2048) unknown.add('Malformed WAV');
          for (var i = 0; i < bytes.length ~/ 4; i++) {
            use(
              i * 4,
              4,
              'sound slot ${i + 1}',
              sound: true,
              registration: true,
            );
          }
        case 'UNIS':
        case 'UNIx':
          if (bytes.length != (section.name == 'UNIS' ? 4048 : 4168)) {
            unknown.add('Malformed ${section.name}');
          }
          for (var i = 0; i < 228; i++) {
            use(3192 + i * 2, 2, 'unit $i');
          }
        case 'TRIG':
        case 'MBRF':
          if (bytes.length % 2400 != 0) {
            unknown.add('Truncated ${section.name}');
          }
          for (var r = 0; r < bytes.length ~/ 2400; r++) {
            if (section.name == 'TRIG') {
              for (var c = 0; c < 16; c++) {
                final slot = bytes.sublist(
                  r * 2400 + c * 20,
                  r * 2400 + (c + 1) * 20,
                );
                if (slot.any((b) => b != 0) &&
                    !ChkTrigger.editable(false, slot)) {
                  unknown.add('Raw condition in trigger ${r + 1}');
                }
              }
            }
            for (var a = 0; a < 64; a++) {
              final o = r * 2400 + 320 + a * 32, type = bytes[o + 26];
              if (type == 0 && bytes.sublist(o, o + 32).every((b) => b == 0)) {
                continue;
              }
              if (section.name == 'TRIG') {
                final slot = bytes.sublist(o, o + 32);
                if (!ChkTrigger.editable(true, slot)) {
                  unknown.add('Raw action in trigger ${r + 1}');
                  continue;
                }
                for (final arg in TriggerOpcodes.find(
                  true,
                  type,
                )!.arguments.where((a) => a.reference == 'string')) {
                  use(
                    o + arg.offset,
                    4,
                    'trigger ${r + 1} action ${a + 1} ${arg.name}',
                    sound: arg.offset == 8,
                  );
                }
              } else {
                if (type == 0 ||
                    type > 9 ||
                    bytes[o + 29] != 0 ||
                    bytes[o + 30] != 0 ||
                    bytes[o + 31] != 0) {
                  unknown.add('Raw briefing action');
                  continue;
                }
                if ({3, 4, 8}.contains(type)) {
                  use(o + 4, 4, 'briefing ${r + 1} action ${a + 1} text');
                }
                if ({2, 8}.contains(type)) {
                  use(
                    o + 8,
                    4,
                    'briefing ${r + 1} action ${a + 1} sound',
                    sound: true,
                  );
                }
              }
            }
          }
        default:
          if (!opaqueSafe.contains(section.name)) {
            unknown.add('Uninterpreted ${section.name} section');
          }
      }
    }
    final names = doc.sections.map((s) => s.name).toList();
    if (names.toSet().length != names.length) {
      unknown.add('Duplicate CHK sections');
    }
    return ResourceReferences(
      List.unmodifiable(uses),
      List.unmodifiable(unknown.toSet()),
    );
  }

  static RawChkDocument edit(
    RawChkDocument doc,
    int id,
    String text, {
    StringUse? onlyUse,
    bool clear = false,
  }) {
    final view = table(doc);
    if (view.entryForId(id)?.isStructurallyValid != true) {
      throw const FormatException('Invalid string ID.');
    }
    final refs = references(doc);
    if (refs.uses.any((u) => u.id == id && u.sound) &&
        (onlyUse == null || onlyUse.sound)) {
      throw StateError(
        'Sound path references are managed through sound import/delete. Separate a text reference to edit its text.',
      );
    }
    if (clear &&
        (refs.uncertainties.isNotEmpty || refs.uses.any((u) => u.id == id))) {
      throw StateError(
        'Referenced or incompletely traced strings cannot be cleared.',
      );
    }
    if (text.contains('\u0000')) {
      throw const FormatException('NUL is not allowed.');
    }
    final raw = utf8.encode(clear ? '' : text);
    if (onlyUse == null) {
      return doc.replaceSection(
        view.sectionIndex,
        view.withAppendedRawString(stringId: id, rawBytes: raw),
      );
    }
    if (!refs.uses.any(
      (u) =>
          u.section == onlyUse.section &&
          u.offset == onlyUse.offset &&
          u.width == onlyUse.width &&
          u.sound == onlyUse.sound &&
          u.id == id,
    )) {
      throw StateError('The selected reference changed.');
    }
    final added = view.withAddedRawString(rawBytes: raw);
    if (onlyUse.width == 2 && added.stringId > 65535) {
      throw StateError('This reference requires a 16-bit string ID.');
    }
    doc = doc.replaceSection(view.sectionIndex, added.section);
    final section = doc.sections[onlyUse.section],
        bytes = Uint8List.fromList(section.payload),
        data = ByteData.sublistView(Uint8List.fromList(section.payload));
    if (onlyUse.width == 2) {
      data.setUint16(onlyUse.offset, added.stringId, Endian.little);
    } else {
      data.setUint32(onlyUse.offset, added.stringId, Endian.little);
    }
    bytes.setAll(0, data.buffer.asUint8List());
    return doc.replaceSection(onlyUse.section, section.withPayload(bytes));
  }

  static RawChkDocument registerSound(RawChkDocument doc, String path) {
    final t = table(doc),
        added = t.withAddedRawString(rawBytes: utf8.encode(path));
    final indices = [
      for (var i = 0; i < doc.sections.length; i++)
        if (doc.sections[i].name == 'WAV ') i,
    ];
    if (indices.length > 1 ||
        (indices.isNotEmpty &&
            doc.sections[indices.single].payload.length != 2048)) {
      throw StateError('One valid WAV table is required.');
    }
    final bytes = indices.isEmpty
        ? Uint8List(2048)
        : Uint8List.fromList(doc.sections[indices.single].payload);
    final data = ByteData.sublistView(bytes);
    var slot = -1;
    for (var i = 0; i < 512; i++) {
      if (data.getUint32(i * 4, Endian.little) == 0) {
        slot = i;
        break;
      }
    }
    if (slot < 0) throw StateError('All 512 sound slots are occupied.');
    data.setUint32(slot * 4, added.stringId, Endian.little);
    doc = doc.replaceSection(t.sectionIndex, added.section);
    return indices.isEmpty
        ? doc.appendSection(
            RawChkSection(
              nameBytes: 'WAV '.codeUnits,
              declaredLength: 2048,
              payload: bytes,
              sourceOffset: doc.sourceLength,
              isDirty: true,
            ),
          )
        : doc.replaceSection(
            indices.single,
            doc.sections[indices.single].withPayload(bytes),
          );
  }

  static RawChkDocument unregisterSound(RawChkDocument doc, String path) {
    final t = table(doc), refs = references(doc);
    final ids = t.entries
        .where(
          (e) =>
              e.rawBytes != null &&
              utf8
                      .decode(e.rawBytes!, allowMalformed: true)
                      .replaceAll('/', '\\')
                      .toLowerCase() ==
                  path.toLowerCase(),
        )
        .map((e) => e.stringId)
        .toSet();
    if (refs.uncertainties.isNotEmpty ||
        refs.uses.any((u) => ids.contains(u.id) && !u.registration)) {
      throw StateError(
        'Sound is referenced, or reference coverage is incomplete.',
      );
    }
    for (final use in refs.uses.where(
      (u) => ids.contains(u.id) && u.registration,
    )) {
      final s = doc.sections[use.section],
          bytes = Uint8List.fromList(s.payload);
      ByteData.sublistView(bytes).setUint32(use.offset, 0, Endian.little);
      doc = doc.replaceSection(use.section, s.withPayload(bytes));
    }
    return doc;
  }
}
