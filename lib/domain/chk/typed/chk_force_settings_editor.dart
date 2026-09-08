import 'dart:convert';
import 'dart:typed_data';

import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_metadata_views.dart';
import 'chk_string_views.dart';

final class ChkForceSettings {
  ChkForceSettings(
    this.sectionIndex,
    List<int> assignments,
    List<int> flags,
    List<String?> names,
    List<String?> nameIssues,
  ) : assignments = List.unmodifiable(assignments),
      flags = List.unmodifiable(flags),
      names = List.unmodifiable(names),
      nameIssues = List.unmodifiable(nameIssues);
  final int sectionIndex;
  final List<int> assignments;
  final List<int> flags;
  final List<String?> names;
  final List<String?> nameIssues;
}

class ChkForceSettingsEditor {
  const ChkForceSettingsEditor();

  ChkStringTableView _table(RawChkDocument document) {
    final raw = document.sections.where(
      (s) => s.name == 'STR ' || s.name == 'STRx',
    );
    final views = const ChkStringViewDecoder().decode(document);
    final tables = [...views.legacyTables, ...views.extendedTables];
    if (raw.length != 1 ||
        tables.length != 1 ||
        !tables.single.canAppendSafely) {
      throw StateError('Force names require one safe STR or STRx table.');
    }
    return tables.single;
  }

  ChkForceSettings read(RawChkDocument document) {
    final versions = const ChkMetadataViewDecoder().decode(document).versions;
    final indices = [
      for (var i = 0; i < document.sections.length; i++)
        if (document.sections[i].name == 'FORC') i,
    ];
    if (versions.length != 1 ||
        versions.single.knownVersion == null ||
        document.sections.where((s) => s.name == 'VER ').length != 1 ||
        indices.length != 1 ||
        document.sections[indices.single].payload.length != 20) {
      throw StateError(
        'Force settings require one known VER and one 20-byte FORC section.',
      );
    }
    final bytes = document.sections[indices.single].payload;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final names = <String?>[];
    final issues = <String?>[];
    for (var force = 0; force < 4; force++) {
      try {
        final table = _table(document);
        final id = data.getUint16(8 + force * 2, Endian.little);
        final entry = table.entryForId(id);
        if (id != 0 && (entry == null || !entry.isStructurallyValid)) {
          throw StateError('Invalid force name string ID $id.');
        }
        names.add(
          id == 0 ? '' : utf8.decode(entry!.rawBytes!, allowMalformed: false),
        );
        issues.add(null);
      } catch (e) {
        names.add(null);
        issues.add(e.toString());
      }
    }
    return ChkForceSettings(
      indices.single,
      bytes.sublist(0, 8),
      bytes.sublist(16, 20),
      names,
      issues,
    );
  }

  /// Flags are the four supported low bits; reserved high bits are retained.
  Map<int, RawChkSection> edit(
    RawChkDocument document, {
    Map<int, int> assignments = const {},
    Map<int, int> flags = const {},
    Map<int, String> names = const {},
  }) {
    final original = read(document);
    final section = document.sections[original.sectionIndex];
    final bytes = Uint8List.fromList(section.payload);
    final data = ByteData.sublistView(bytes);
    for (final change in assignments.entries) {
      RangeError.checkValueInInterval(change.key, 0, 7, 'player');
      if (bytes[change.key] == change.value) continue;
      RangeError.checkValueInInterval(change.value, 0, 3, 'force');
      bytes[change.key] = change.value;
    }
    for (final change in flags.entries) {
      RangeError.checkValueInInterval(change.key, 0, 3, 'force');
      RangeError.checkValueInInterval(change.value, 0, 15, 'flags');
      bytes[16 + change.key] = (bytes[16 + change.key] & 0xf0) | change.value;
    }
    var updated = document;
    final replacements = <int, RawChkSection>{};
    for (final change in names.entries) {
      RangeError.checkValueInInterval(change.key, 0, 3, 'force');
      if (original.nameIssues[change.key] != null) {
        throw StateError(original.nameIssues[change.key]!);
      }
      if (original.names[change.key] == change.value) continue;
      var id = 0;
      if (change.value.isNotEmpty) {
        if (change.value.contains('\u0000')) {
          throw ArgumentError('Force names cannot contain NUL.');
        }
        final table = _table(updated);
        if (table.declaredStringCount >= 0xffff) {
          throw StateError('FORC string IDs cannot exceed 65535.');
        }
        final added = table.withAddedRawString(
          rawBytes: utf8.encode(change.value),
        );
        replacements[table.sectionIndex] = added.section;
        updated = updated.replaceSection(table.sectionIndex, added.section);
        id = added.stringId;
      }
      data.setUint16(8 + change.key * 2, id, Endian.little);
    }
    if (List.generate(
      20,
      (i) => bytes[i] != section.payload[i],
    ).any((v) => v)) {
      replacements[original.sectionIndex] = section.withPayload(bytes);
    }
    return replacements;
  }
}
