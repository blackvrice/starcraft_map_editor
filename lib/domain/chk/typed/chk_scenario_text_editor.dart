import 'dart:convert';

import '../chk_section_names.dart';
import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_string_views.dart';

/// A validated, lossless editing snapshot of the map's SPRP references.
final class ChkScenarioText {
  const ChkScenarioText(this.title, this.description);

  final String title;
  final String description;
}

class ChkScenarioTextEditor {
  const ChkScenarioTextEditor();

  (ChkScenarioPropertiesView, ChkStringTableView) _views(
    RawChkDocument document,
  ) {
    final properties = document.sections.where(
      ChkSectionNames.isScenarioProperties,
    );
    final tables = document.sections.where(
      (section) =>
          ChkSectionNames.isLegacyStrings(section) ||
          ChkSectionNames.isExtendedStrings(section),
    );
    final views = const ChkStringViewDecoder().decode(document);
    final decodedTables = [...views.legacyTables, ...views.extendedTables];
    if (properties.length != 1 ||
        views.scenarioProperties.length != 1 ||
        tables.length != 1 ||
        decodedTables.length != 1 ||
        !decodedTables.single.canAppendSafely) {
      throw StateError(
        'Map information requires one valid SPRP and one safe STR or STRx table.',
      );
    }
    return (views.scenarioProperties.single, decodedTables.single);
  }

  ChkScenarioText read(RawChkDocument document) {
    final (properties, table) = _views(document);
    String resolve(ChkStringReference ref) {
      if (ref.isNone) return '';
      final entry = ref.resolve(table);
      if (entry == null || !entry.isStructurallyValid) {
        throw StateError('A map information string reference is invalid.');
      }
      // Never silently replace undecodable source bytes during a form edit.
      return utf8.decode(entry.rawBytes!, allowMalformed: false);
    }

    return ChkScenarioText(
      resolve(properties.scenarioName),
      resolve(properties.scenarioDescription),
    );
  }

  Map<int, RawChkSection> edit(
    RawChkDocument document, {
    required String title,
    required String description,
  }) {
    final original = read(document);
    final (properties, initialTable) = _views(document);
    var table = initialTable;
    var updated = document;
    final replacements = <int, RawChkSection>{};
    int replace(String previous, String next, int id) {
      if (previous == next) return id;
      if (next.isEmpty) return 0;
      if (next.contains('\u0000')) {
        throw ArgumentError('Map text cannot contain a NUL character.');
      }
      if (table.declaredStringCount >= 0xffff) {
        throw StateError(
          'SPRP cannot reference another string above ID 65535.',
        );
      }
      final added = table.withAddedRawString(rawBytes: utf8.encode(next));
      replacements[table.sectionIndex] = added.section;
      updated = updated.replaceSection(table.sectionIndex, added.section);
      table = _views(updated).$2;
      return added.stringId;
    }

    final titleId = replace(
      original.title,
      title,
      properties.scenarioName.stringId,
    );
    final descriptionId = replace(
      original.description,
      description,
      properties.scenarioDescription.stringId,
    );
    if (titleId != properties.scenarioName.stringId ||
        descriptionId != properties.scenarioDescription.stringId) {
      replacements[properties.sectionIndex] = properties.withReferences(
        scenarioNameStringId: titleId,
        scenarioDescriptionStringId: descriptionId,
      );
    }
    return replacements;
  }
}
