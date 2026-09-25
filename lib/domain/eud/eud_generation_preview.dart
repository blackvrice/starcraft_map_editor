import 'dart:convert';

import 'eud_field_manifest.dart';
import 'eud_project.dart';

/// Deterministic, non-executable input for a future verified SCData generator.
/// Merely accepting an override must never activate compilation or runtime use.
final class EudGenerationPreview {
  EudGenerationPreview(EudProject project) {
    final issues = project.validationIssues;
    if (issues.isNotEmpty) throw FormatException(issues.join(', '));
    final overrides = [...project.overrides]
      ..sort((a, b) {
        final ta = EudFieldManifest.find(a.field)!.table.name;
        final tb = EudFieldManifest.find(b.field)!.table.name;
        final table = ta.compareTo(tb);
        if (table != 0) return table;
        final target = a.targetId.compareTo(b.targetId);
        return target != 0 ? target : a.field.compareTo(b.field);
      });
    manifest =
        '${const JsonEncoder.withIndent('  ').convert({
          'format': 'starcraft-eud-generation-preview',
          'version': 1,
          'executable': false,
          'runtimeStatus': 'unverified',
          'mapSha256': project.mapSha256,
          'tool': {'euddraft': EudFieldManifest.euddraftVersion, 'eudplib': EudFieldManifest.eudplibVersion, 'apiRevision': EudFieldManifest.sourceRevision},
          'initialization': 'start-once-candidate',
          'userHookOrder': 'unverified',
          'currentUnitShieldPolicy': 'not-generated',
          'operations': [
            for (final item in overrides) {'table': EudFieldManifest.find(item.field)!.table.name, 'id': item.targetId, 'field': item.field, 'candidateMember': EudFieldManifest.find(item.field)!.member, 'value': item.value, 'overrideChk': item.overrideChk},
          ],
        })}\n';
  }
  late final String manifest;
}
