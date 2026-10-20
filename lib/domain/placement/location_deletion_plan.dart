import '../chk/chk.dart';
import '../chk/typed/chk_trigger_editor.dart';
import '../chk/typed/chk_trigger_portability.dart';

/// Clears explicit MRGN slots without renumbering IDs or touching strings.
/// The proof covers canonical stored TRIG/MBRF, not external executable source.
final class LocationDeletionPlan {
  LocationDeletionPlan._(
    this.document,
    this.sectionIndex,
    this.replacement,
    Set<int> indices,
  ) : recordIndices = Set.unmodifiable(indices);

  static const maximumSelectedLocations = 254;
  static const maximumTriggerRecords = 4096;
  final RawChkDocument document;
  final int sectionIndex;
  final RawChkSection replacement;
  final Set<int> recordIndices;

  static LocationDeletionPlan create({
    required RawChkDocument document,
    required Iterable<int> recordIndices,
  }) {
    final requested = recordIndices.take(maximumSelectedLocations + 1).toList();
    final selected = requested.toSet();
    if (requested.isEmpty ||
        requested.length > maximumSelectedLocations ||
        selected.length != requested.length) {
      throw StateError('LOCATION_DELETE: selection count or duplicates');
    }
    final raw = document.sections.where(
      (s) => s.hasNameBytes(ChkSectionNames.locations),
    );
    final views = const ChkObjectViewDecoder()
        .decode(document)
        .locationSections;
    if (raw.length != 1 ||
        views.length != 1 ||
        !{64 * 20, 255 * 20}.contains(raw.single.declaredLength)) {
      throw StateError('LOCATION_DELETE: requires one complete MRGN section');
    }
    final view = views.single;
    for (final index in selected) {
      if (index < 0 ||
          index >= view.locations.length ||
          index == 63 ||
          view.locations[index].isBlank) {
        throw StateError(
          'LOCATION_DELETE: invalid, blank or Anywhere selection',
        );
      }
    }
    final triggerBytes = document.sections
        .where((s) => s.name == 'TRIG' || s.name == 'MBRF')
        .fold<int>(0, (n, s) => n + s.declaredLength);
    if (triggerBytes > maximumTriggerRecords * 2400) {
      throw StateError('LOCATION_DELETE: trigger scan limit');
    }
    for (final briefing in [false, true]) {
      for (final trigger in ChkTriggers.read(
        document,
        briefing: briefing,
      ).records) {
        ChkTriggerPortability.requireCanonical(
          trigger,
          document,
          diagnosticPrefix: 'LOCATION_DELETE',
        );
        // Disabled records/slots can be enabled later and still reserve the ID.
        for (final action in briefing ? [true] : [false, true]) {
          for (var i = 0; i < (action ? 64 : 16); i++) {
            final slot = trigger.slot(action, i);
            if (slot.every((b) => b == 0)) continue;
            final op = TriggerOpcodes.find(
              action,
              ChkTrigger.type(action, slot),
              briefing: briefing,
            )!;
            for (final arg in op.arguments.where(
              (a) => a.reference == 'location',
            )) {
              if (selected.contains(ChkTrigger.argument(slot, arg) - 1)) {
                throw StateError('LOCATION_DELETE: referenced location');
              }
            }
          }
        }
      }
    }
    return LocationDeletionPlan._(
      document,
      view.sectionIndex,
      const ChkObjectSectionEditor().deleteLocations(view, selected),
      selected,
    );
  }
}
