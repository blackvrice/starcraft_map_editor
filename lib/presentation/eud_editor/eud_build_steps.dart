import 'package:flutter/material.dart';

import '../../application/eud/eud_build_controller.dart';
import '../localization/l10n.dart';

/// Whether the map document is ready to be used as the build input.
enum EudBuildMapStep { none, dirty, saved }

/// Whether the entry epScript is saved to a file.
enum EudBuildSourceStep { untitled, dirty, saved }

enum _StepState { done, attention, error, active, pending }

/// A four-step strip that answers "what do I still need to do before I can
/// build?" above the epScript editor.
///
/// It only reflects existing controller state; it never saves or builds by
/// itself. The optional callbacks expose the next action on the step that
/// needs it.
class EudBuildSteps extends StatelessWidget {
  const EudBuildSteps({
    required this.map,
    required this.source,
    required this.status,
    this.onPrepare,
    this.onBuild,
    super.key,
  });

  final EudBuildMapStep map;
  final EudBuildSourceStep source;
  final EudBuildStatus status;
  final VoidCallback? onPrepare;
  final VoidCallback? onBuild;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (mapState, mapSub) = switch (map) {
      EudBuildMapStep.none => (_StepState.error, l10n.buildStepMapNone),
      EudBuildMapStep.dirty => (_StepState.attention, l10n.buildStepMapDirty),
      EudBuildMapStep.saved => (_StepState.done, l10n.buildStepMapSaved),
    };
    final (sourceState, sourceSub) = switch (source) {
      EudBuildSourceStep.untitled => (
        _StepState.attention,
        l10n.buildStepSourceUntitled,
      ),
      EudBuildSourceStep.dirty => (
        _StepState.attention,
        l10n.buildStepSourceDirty,
      ),
      EudBuildSourceStep.saved => (_StepState.done, l10n.buildStepSourceSaved),
    };
    final prepared = status != EudBuildStatus.notConfigured;
    final earlierDone =
        map == EudBuildMapStep.saved &&
        source == EudBuildSourceStep.saved &&
        prepared;
    final (runState, runSub) = switch (status) {
      EudBuildStatus.running ||
      EudBuildStatus.cancelling ||
      EudBuildStatus.finalizing => (_StepState.active, l10n.buildStepRunBusy),
      EudBuildStatus.succeeded => (_StepState.done, l10n.buildStepRunSucceeded),
      EudBuildStatus.failed => (_StepState.error, l10n.buildStepRunFailed),
      EudBuildStatus.cancelled => (
        _StepState.attention,
        l10n.buildStepRunCancelled,
      ),
      EudBuildStatus.ready || EudBuildStatus.notConfigured =>
        earlierDone
            ? (_StepState.pending, l10n.buildStepRunReady)
            : (_StepState.pending, l10n.buildStepRunBlocked),
    };

    return Semantics(
      container: true,
      label: l10n.buildStepsLabel,
      child: Container(
        key: const Key('eud-build-steps'),
        color: const Color(0xFF16191D),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: _Step(
                key: const Key('eud-build-step-map'),
                number: 1,
                title: l10n.buildStepMap,
                subtitle: mapSub,
                state: mapState,
              ),
            ),
            const _Connector(),
            Expanded(
              child: _Step(
                key: const Key('eud-build-step-source'),
                number: 2,
                title: l10n.buildStepSource,
                subtitle: sourceSub,
                state: sourceState,
              ),
            ),
            const _Connector(),
            Expanded(
              child: _Step(
                key: const Key('eud-build-step-prepare'),
                number: 3,
                title: l10n.buildStepPrepare,
                subtitle: prepared
                    ? l10n.buildStepPrepareReady
                    : l10n.buildStepPrepareNeeded,
                state: prepared ? _StepState.done : _StepState.attention,
                action: prepared || onPrepare == null
                    ? null
                    : TextButton(
                        key: const Key('eud-build-step-prepare-action'),
                        onPressed: onPrepare,
                        child: Text(l10n.buildStepPrepareAction),
                      ),
              ),
            ),
            const _Connector(),
            Expanded(
              child: _Step(
                key: const Key('eud-build-step-run'),
                number: 4,
                title: l10n.buildStepRun,
                subtitle: runSub,
                state: runState,
                action: onBuild == null || runState == _StepState.active
                    ? null
                    : FilledButton.icon(
                        key: const Key('eud-build-step-run-action'),
                        onPressed: onBuild,
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: Text(l10n.toolbarBuildEud),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: l10n.buildSummaryUnchanged,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: Color(0xFF9FDCB2),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(
                      l10n.buildSafetyNote,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9FDCB2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 2,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: const Color(0xFF3A4048),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    this.action,
    super.key,
  });

  final int number;
  final String title;
  final String subtitle;
  final _StepState state;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (state) {
      _StepState.done => (
        const Color(0xFF16231A),
        const Color(0xFF2F4A36),
        const Color(0xFF6CC48A),
      ),
      _StepState.error => (
        const Color(0xFF2A1A1C),
        const Color(0xFF5A3A3E),
        const Color(0xFFEF8A91),
      ),
      _StepState.attention || _StepState.active => (
        const Color(0xFF2A2418),
        const Color(0xFF6A5431),
        const Color(0xFFF0C982),
      ),
      _StepState.pending => (
        Colors.transparent,
        const Color(0xFF3A4048),
        const Color(0xFF8B939C),
      ),
    };
    final badge = switch (state) {
      _StepState.done => const Icon(Icons.check_rounded, size: 15),
      _StepState.error => const Icon(Icons.close_rounded, size: 15),
      _StepState.active => const SizedBox(
        width: 13,
        height: 13,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      _ => Text(
        '$number',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    };
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
          ),
          child: IconTheme(
            data: IconThemeData(color: foreground),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: badge,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      state == _StepState.error ||
                          state == _StepState.attention ||
                          state == _StepState.active
                      ? foreground
                      : const Color(0xFFDFE3E8),
                ),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFFA7AFB8)),
              ),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 6), action!],
      ],
    );
  }
}
