import '../../diagnostics/editor_diagnostic.dart';
import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_metadata_views.dart';
import 'chk_object_views.dart';

enum ChkPlayerField {
  owner('OWNR', 12, {
    0: 'Inactive',
    3: 'Rescue passive',
    5: 'Computer',
    6: 'Human',
    7: 'Neutral',
  }),
  race('SIDE', 12, {
    0: 'Zerg',
    1: 'Terran',
    2: 'Protoss',
    3: 'Independent',
    4: 'Neutral',
    5: 'User selectable',
    6: 'Random',
    7: 'Inactive',
  }),
  color('COLR', 8, {
    0: 'Red',
    1: 'Blue',
    2: 'Teal',
    3: 'Purple',
    4: 'Orange',
    5: 'Brown',
    6: 'White',
    7: 'Yellow',
    8: 'Green',
    9: 'Pale yellow',
    10: 'Tan',
    11: 'Azure',
  });

  const ChkPlayerField(this.sectionName, this.length, this.options);
  final String sectionName;
  final int length;
  final Map<int, String> options;
}

final class ChkPlayerSettingGroup {
  ChkPlayerSettingGroup(
    this.field,
    this.sectionIndex,
    List<int>? values,
    this.issue,
  ) : values = values == null ? null : List.unmodifiable(values);
  final ChkPlayerField field;
  final int? sectionIndex;
  final List<int>? values;
  final String? issue;
  bool get canEdit => issue == null;
}

final class ChkPlayerChange {
  const ChkPlayerChange(this.player, this.field, this.value);
  final int player;
  final ChkPlayerField field;
  final int value;
}

class ChkPlayerSettingsEditor {
  const ChkPlayerSettingsEditor();
  static const diagnosticPrefix = 'CHK_PLAYER_SETTINGS_';

  List<ChkPlayerSettingGroup> read(RawChkDocument document) {
    final versions = const ChkMetadataViewDecoder().decode(document).versions;
    final knownVersion =
        versions.length == 1 &&
        versions.single.knownVersion != null &&
        document.sections.where((s) => s.name == 'VER ').length == 1;
    return [
      for (final field in ChkPlayerField.values)
        _readGroup(document, field, knownVersion),
    ];
  }

  ChkPlayerSettingGroup _readGroup(
    RawChkDocument document,
    ChkPlayerField field,
    bool knownVersion,
  ) {
    final indices = [
      for (var i = 0; i < document.sections.length; i++)
        if (document.sections[i].name == field.sectionName) i,
    ];
    if (indices.length != 1) {
      return ChkPlayerSettingGroup(
        field,
        null,
        null,
        '${field.sectionName}: expected one section; found ${indices.length}.',
      );
    }
    final index = indices.single;
    final payload = document.sections[index].payload;
    if (payload.length != field.length) {
      return ChkPlayerSettingGroup(
        field,
        index,
        null,
        '${field.sectionName}: expected ${field.length} bytes; found ${payload.length}.',
      );
    }
    final issue = !knownVersion
        ? 'A single known VER section is required.'
        : field == ChkPlayerField.color &&
              document.sections.any((s) => s.name == 'CRGB')
        ? 'CRGB color settings are present. COLR editing is unavailable until their interaction is supported.'
        : null;
    return ChkPlayerSettingGroup(field, index, payload, issue);
  }

  Map<int, RawChkSection> edit(
    RawChkDocument document,
    Iterable<ChkPlayerChange> changes,
  ) {
    final groups = read(document);
    final payloads = <int, List<int>>{};
    final seen = <(int, ChkPlayerField)>{};
    for (final change in changes) {
      RangeError.checkValueInInterval(change.player, 0, 7, 'player');
      if (!seen.add((change.player, change.field))) {
        throw ArgumentError('A player field may be updated only once.');
      }
      final group = groups[change.field.index];
      if (!group.canEdit) throw StateError(group.issue!);
      // Unknown existing values are preserved by omitting unchanged fields.
      if (group.values![change.player] == change.value) continue;
      if (!change.field.options.containsKey(change.value)) {
        throw ArgumentError(
          'Unsupported ${change.field.name} ID: ${change.value}.',
        );
      }
      final bytes = payloads.putIfAbsent(
        group.sectionIndex!,
        () => group.values!.toList(),
      );
      bytes[change.player] = change.value;
    }
    return {
      for (final entry in payloads.entries)
        entry.key: document.sections[entry.key].withPayload(entry.value),
    };
  }

  List<EditorDiagnostic> diagnostics(RawChkDocument document) {
    final owner = read(document).first;
    if (owner.values == null) return const [];
    final result = <EditorDiagnostic>[];
    void warn(
      String code,
      String message, {
      int? offset,
      String section = 'OWNR',
    }) {
      result.add(
        EditorDiagnostic(
          code: '$diagnosticPrefix$code',
          message: message,
          severity: DiagnosticSeverity.warning,
          stage: DiagnosticStage.validate,
          sectionName: section,
          byteOffset: offset,
        ),
      );
    }

    final rawUnits = document.sections.where((s) => s.name == 'UNIT');
    if (rawUnits.any(
      (s) => s.payload.length % ChkUnitPlacement.recordLength != 0,
    )) {
      warn(
        'START_UNAVAILABLE',
        'Start locations cannot be checked: a UNIT section is malformed.',
        section: 'UNIT',
      );
      return result;
    }
    final counts = List<int>.filled(8, 0);
    final views = const ChkObjectViewDecoder().decode(document);
    for (final section in views.unitSections) {
      for (final unit in section.units) {
        if (unit.unitType != 214) continue;
        if (unit.owner >= 8) {
          warn(
            'START_OWNER',
            'Start location has non-playable owner ID ${unit.owner}.',
            section: 'UNIT',
          );
        } else {
          counts[unit.owner]++;
        }
      }
    }
    for (var player = 0; player < 8; player++) {
      final type = owner.values![player];
      final active = {1, 2, 5, 6}.contains(type);
      final offset =
          document.sections[owner.sectionIndex!].sourceOffset + 8 + player;
      if (counts[player] > 1) {
        warn(
          'START_DUPLICATE',
          'Player ${player + 1} has ${counts[player]} start locations.',
          offset: offset,
        );
      } else if (active && counts[player] == 0) {
        warn(
          'START_MISSING',
          'Player ${player + 1} has no start location; check the intended UMS setup.',
          offset: offset,
        );
      }
      if ({0, 8}.contains(type) && counts[player] > 0) {
        warn(
          'START_INACTIVE',
          'Inactive player ${player + 1} owns a start location.',
          offset: offset,
        );
      }
    }
    return result;
  }
}
