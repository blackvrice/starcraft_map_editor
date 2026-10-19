import '../chk/chk.dart';
import '../chk/chk_basic_editing.dart';

/// Deletes explicit original UNIT indices after validating both outgoing and
/// incoming links. A surviving mutual peer is unlinked, never auto-deleted.
final class UnitDeletionPlan {
  UnitDeletionPlan._({
    required this.document,
    required this.sectionIndex,
    required this.replacement,
    required this.unitCount,
    required Set<int> unlinkedPeerRecordIndices,
  }) : unlinkedPeerRecordIndices = Set.unmodifiable(unlinkedPeerRecordIndices);

  static const maximumSelectedUnits = 256;
  final RawChkDocument document;
  final int sectionIndex;
  final RawChkSection replacement;
  final int unitCount;
  final Set<int> unlinkedPeerRecordIndices;

  static UnitDeletionPlan create({
    required RawChkDocument document,
    required Iterable<int> recordIndices,
  }) {
    final requested = recordIndices.take(maximumSelectedUnits + 1).toList();
    final selected = requested.toSet();
    if (requested.isEmpty ||
        requested.length > maximumSelectedUnits ||
        selected.length != requested.length) {
      throw StateError('UNIT_DELETE: selection count or duplicates');
    }
    final raw = document.sections.where(
      (s) => s.hasNameBytes(ChkSectionNames.unitPlacements),
    );
    final views = const ChkObjectViewDecoder().decode(document).unitSections;
    if (raw.length != 1 ||
        views.length != 1 ||
        raw.single.declaredLength !=
            views.single.units.length * ChkUnitPlacement.recordLength) {
      throw StateError('UNIT_DELETE: requires one complete UNIT section');
    }
    final view = views.single;
    for (final index in selected) {
      if (index < 0 || index >= view.units.length) {
        throw StateError('UNIT_DELETE: invalid selected unit');
      }
    }
    final ids = {
      for (final index in selected)
        if (view.units[index].classId != 0) view.units[index].classId,
    };
    final affected = {...selected};
    for (final unit in view.units) {
      if (unit.relationClassId != 0 && ids.contains(unit.relationClassId)) {
        affected.add(unit.recordIndex);
        // A valid mutual link contributes at most one peer per selected unit.
        if (affected.length > selected.length * 2) {
          throw StateError('UNIT_DELETE: ambiguous incoming relationships');
        }
      }
    }
    final unlinked = const ChkBasicEditing().unlinkUnits(document, affected);
    final unlinkedView = const ChkObjectViewDecoder()
        .decode(unlinked)
        .unitSections
        .single;
    return UnitDeletionPlan._(
      document: document,
      sectionIndex: view.sectionIndex,
      replacement: const ChkObjectSectionEditor().deleteUnits(
        unlinkedView,
        selected,
      ),
      unitCount: selected.length,
      unlinkedPeerRecordIndices: affected.difference(selected),
    );
  }
}
