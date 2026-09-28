import 'dart:typed_data';
import '../chk/raw_chk_document.dart';
import '../chk/typed/chk_resource_editor.dart';
import 'eud_project.dart';
import 'eud_rule_expression.dart';

abstract final class EudRuleReferences {
  static List<String> validate(EudProject project, RawChkDocument document) {
    final issues = <String>[];
    for (final rule in project.rules.where((r) => r.enabled)) {
      final e = rule.extension;
      if (e == null) continue;
      if (e.usesLocation) {
        final sections = document.sections
            .where((s) => s.name == 'MRGN')
            .toList();
        if (sections.length != 1 ||
            sections.single.payload.length % 20 != 0 ||
            e.target * 20 > sections.single.payload.length) {
          issues.add('${rule.id}:unavailableLocation:${e.target}');
        }
      }
      if (e.action == EudRuleAction.sound) {
        try {
          final table = ChkResourceEditor.table(document, forEditing: false);
          final entry = table.entryForId(e.target);
          final sections = document.sections
              .where((s) => s.name == 'WAV ')
              .toList();
          var registered = false;
          if (sections.length == 1 && sections.single.payload.length == 2048) {
            final data = ByteData.sublistView(
              Uint8List.fromList(sections.single.payload),
            );
            for (var i = 0; i < 2048; i += 4) {
              if (data.getUint32(i, Endian.little) == e.target) {
                registered = true;
              }
            }
          }
          if (!registered ||
              entry?.isStructurallyValid != true ||
              entry!.rawBytes!.isEmpty) {
            issues.add('${rule.id}:unregisteredSound:${e.target}');
          }
        } on FormatException {
          issues.add('${rule.id}:ambiguousSoundTable');
        }
      }
    }
    return issues;
  }
}
