import 'dart:typed_data';
import '../chk/raw_chk_document.dart';
import '../chk/typed/chk_trigger_editor.dart';
import 'eud_dat_layout.dart';
import 'eud_field_manifest.dart';
import 'eud_project.dart';
import 'eud_rule_expression.dart';

enum EudConflictKind {
  memoryWrite,
  memoryRead,
  ruleWrite,
  sourceWrite,
  unresolved,
}

final class EudConflict {
  const EudConflict(this.kind, this.origin, this.target);
  final EudConflictKind kind;
  final String origin, target;
}

/// Conservative static diagnostics. It never executes code or claims semantic equivalence.
abstract final class EudConflictAnalysis {
  static List<EudConflict> analyze(
    EudProject project, {
    RawChkDocument? document,
    String? userSource,
  }) {
    final results = <EudConflict>[];
    final ranges = <({int address, int width, String target})>[];
    for (final item in project.overrides) {
      final layout = EudDatLayout.memory[item.field];
      final field = EudFieldManifest.find(item.field);
      if (layout == null ||
          field == null ||
          field.validate(item.targetId, item.value) != null) {
        results.add(
          EudConflict(EudConflictKind.unresolved, 'project', item.identity),
        );
        continue;
      }
      ranges.add((
        address: layout.address + layout.stride * item.targetId,
        width: layout.stride,
        target: item.identity,
      ));
    }
    void memory(
      int address,
      String origin,
      EudConflictKind kind, [
      int mask = 0xffffffff,
    ]) {
      for (final range in ranges) {
        var overlaps = false;
        for (var b = 0; b < 4; b++) {
          if (mask >> (b * 8) & 255 != 0 &&
              address + b >= range.address &&
              address + b < range.address + range.width) {
            overlaps = true;
          }
        }
        if (overlaps) results.add(EudConflict(kind, origin, range.target));
      }
    }

    if (document == null) {
      results.add(
        const EudConflict(EudConflictKind.unresolved, 'TRIG', 'No current map'),
      );
    } else if (document.sections.any((s) => s.name == 'TRIG')) {
      try {
        final records = ChkTriggers.read(document).records;
        for (var i = 0; i < records.length; i++) {
          final trigger = records[i];
          if (!trigger.enabled ||
              !trigger.bytes.sublist(2372, 2399).any((v) => v != 0)) {
            continue;
          }
          for (final action in [false, true]) {
            for (var j = 0; j < (action ? 64 : 16); j++) {
              final slot = trigger.slot(action, j),
                  type = ChkTrigger.type(action, trigger.slot(action, j));
              if (type == 0 || slot[action ? 28 : 17] & 2 != 0) continue;
              final data = ByteData.sublistView(Uint8List.fromList(slot));
              final origin =
                  'TRIG #${i + 1} ${action ? 'action' : 'condition'} #${j + 1}';
              if (type == (action ? 45 : 15)) {
                final player = data.getUint32(action ? 16 : 4, Endian.little);
                final unit = data.getUint16(action ? 24 : 12, Endian.little);
                final masked =
                    data.getUint16(action ? 30 : 18, Endian.little) == 0x4353;
                if (player <= 11 && unit < 228 && !masked) continue;
                if (player == 13 || (player >= 14 && player <= 26)) {
                  results.add(
                    EudConflict(
                      EudConflictKind.unresolved,
                      origin,
                      'Dynamic death-counter player',
                    ),
                  );
                } else {
                  final address =
                      (0x58a364 + 4 * player + 48 * unit) & 0xffffffff;
                  memory(
                    address,
                    origin,
                    action
                        ? EudConflictKind.memoryWrite
                        : EudConflictKind.memoryRead,
                    masked ? data.getUint32(0, Endian.little) : 0xffffffff,
                  );
                }
              } else if (action && [26, 38, 49, 50, 51].contains(type)) {
                final player = data.getUint32(16, Endian.little);
                final resource = data.getUint16(24, Endian.little);
                for (final rule in project.rules.where((r) => r.enabled)) {
                  final target = rule.writeTarget;
                  final matches = type == 26
                      ? (player == rule.player || player >= 13) &&
                            ((resource == 0 || resource == 2) &&
                                    target == '${rule.player}:ore' ||
                                (resource == 1 || resource == 2) &&
                                    target == '${rule.player}:gas')
                      : type == 38
                      ? target == 'location:${data.getUint32(0, Endian.little)}'
                      : rule.extension?.action ==
                                switch (type) {
                                  49 => EudRuleAction.unitHp,
                                  50 => EudRuleAction.unitEnergy,
                                  _ => EudRuleAction.unitShields,
                                } &&
                            (player == rule.player || player >= 13) &&
                            (resource == rule.extension?.unitType ||
                                resource >= 228);
                  if (matches) {
                    results.add(
                      EudConflict(
                        EudConflictKind.ruleWrite,
                        origin,
                        'rule:${rule.id} ($target)',
                      ),
                    );
                  }
                }
              } else if (!ChkTrigger.editable(action, slot)) {
                results.add(
                  EudConflict(
                    EudConflictKind.unresolved,
                    origin,
                    'Unsupported opcode $type',
                  ),
                );
              }
            }
          }
        }
      } on FormatException catch (e) {
        results.add(EudConflict(EudConflictKind.unresolved, 'TRIG', e.message));
      }
    }
    if (userSource != null && userSource.trim().isNotEmpty) {
      final code = _strip(userSource);
      int? integer(String token) => int.tryParse(token.trim());
      String origin(int offset) =>
          'source:${'\n'.allMatches(code.substring(0, offset)).length + 1}';
      final assignments = RegExp(
        r'\b(TrgUnit|Weapon|Flingy|Upgrade|Tech|TrgPlayer|Sprite|Image)\s*\(\s*(0[xX][0-9a-fA-F]+|\d+)\s*\)\s*\.\s*(\w+)\s*(?:\+=|-=|\|=|&=|\^=|=(?!=))',
      );
      for (final hit in assignments.allMatches(code)) {
        final member = '${hit[1]}.${hit[3]}', id = integer(hit[2]!);
        if (id == null) continue;
        for (final o in project.overrides) {
          if (EudFieldManifest.find(o.field)?.member == member &&
              o.targetId == id) {
            results.add(
              EudConflict(
                EudConflictKind.sourceWrite,
                origin(hit.start),
                o.identity,
              ),
            );
          }
        }
      }
      for (final hit in RegExp(
        r'\b(SetMemory|SetMemoryX|SetMemoryEPD|SetMemoryXEPD)\s*\(\s*(0[xX][0-9a-fA-F]+|\d+)\s*,',
      ).allMatches(code)) {
        final number = integer(hit[2]!);
        if (number == null || number < 0 || number > 0xffffffff) continue;
        final address = hit[1]!.endsWith('EPD')
            ? (0x58a364 + 4 * number) & 0xffffffff
            : number;
        // A mask expression can be dynamic; use the whole dword conservatively.
        memory(address, origin(hit.start), EudConflictKind.sourceWrite);
      }
      results.add(
        const EudConflict(
          EudConflictKind.unresolved,
          'source',
          'Imports, aliases, expressions, dynamic addresses and other hooks require manual review',
        ),
      );
    } else {
      results.add(
        const EudConflict(
          EudConflictKind.unresolved,
          'source',
          'User files/plugins have not been analyzed',
        ),
      );
    }
    return List.unmodifiable(results);
  }

  /// Preserve offsets/lines, remove strings and //, /* */, # comments.
  static String _strip(String source) {
    final result = source.split('');
    void blank(int from, int to) {
      for (var k = from; k < to; k++) {
        if (source[k] != '\n') result[k] = ' ';
      }
    }

    var i = 0;
    while (i < source.length) {
      final start = i;
      if (source[i] == '#' || source.startsWith('//', i)) {
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        blank(start, i);
      } else if (source.startsWith('/*', i)) {
        final end = source.indexOf('*/', i + 2);
        i = end < 0 ? source.length : end + 2;
        blank(start, i);
      } else if (source[i] == '"' || source[i] == "'") {
        final quote = source[i], triple = source.startsWith(source[i] * 3, i);
        final delimiter = triple ? quote * 3 : quote;
        i += delimiter.length;
        while (i < source.length) {
          if (source[i] == '\\') {
            i = (i + 2).clamp(0, source.length);
          } else if (source.startsWith(delimiter, i)) {
            i += delimiter.length;
            break;
          } else {
            i++;
          }
        }
        blank(start, i);
      } else {
        i++;
      }
    }
    return result.join();
  }
}
