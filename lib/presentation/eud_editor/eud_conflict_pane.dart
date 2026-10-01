import 'package:flutter/material.dart';
import '../../domain/eud/eud_conflict_analysis.dart';
import '../../domain/eud/eud_project.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../localization/l10n.dart';

/// Reports the current in-memory map and explicitly supplied source only.
class EudConflictPane extends StatelessWidget {
  const EudConflictPane({
    required this.project,
    this.document,
    this.userSource,
    super.key,
  });
  final EudProject project;
  final RawChkDocument? document;
  final String? userSource;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final issues = EudConflictAnalysis.analyze(
      project,
      document: document,
      userSource: userSource,
    );
    return ExpansionTile(
      key: const Key('eud-conflict-report'),
      title: Text(
        l.eudConflictTitle(
          issues.where((i) => i.kind != EudConflictKind.unresolved).length,
        ),
      ),
      subtitle: Text(l.eudConflictHelp),
      children: [
        for (final issue in issues)
          ListTile(
            dense: true,
            leading: Icon(
              issue.kind == EudConflictKind.unresolved
                  ? Icons.help_outline
                  : Icons.warning_amber,
            ),
            title: Text('${issue.origin} → ${issue.target}'),
            subtitle: Text(
              l.localeName == 'ko'
                  ? switch (issue.kind) {
                      EudConflictKind.memoryWrite => '메모리 쓰기 겹침',
                      EudConflictKind.memoryRead => '변경된 메모리를 읽는 조건',
                      EudConflictKind.ruleWrite => '실행 규칙과 일반 액션의 쓰기 대상 겹침',
                      EudConflictKind.sourceWrite => '현재 소스의 쓰기 대상 겹침',
                      EudConflictKind.unresolved => '정적 분석 미확인',
                    }
                  : issue.kind.name,
            ),
          ),
      ],
    );
  }
}
