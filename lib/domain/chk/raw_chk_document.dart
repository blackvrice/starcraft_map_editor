import 'raw_chk_section.dart';

class RawChkDocument {
  RawChkDocument({
    required List<RawChkSection> sections,
    required this.sourceLength,
  }) : sections = List.unmodifiable(sections) {
    if (sourceLength < 0) {
      throw RangeError.value(
        sourceLength,
        'sourceLength',
        'A source length cannot be negative.',
      );
    }
  }

  final List<RawChkSection> sections;
  final int sourceLength;

  bool get isDirty => sections.any((section) => section.isDirty);

  RawChkDocument replaceSection(int index, RawChkSection replacement) {
    RangeError.checkValidIndex(index, sections, 'index');

    final updatedSections = sections.toList();
    updatedSections[index] = replacement;

    return RawChkDocument(
      sections: updatedSections,
      sourceLength: sourceLength,
    );
  }

  /// Appends a synthesized section at the end of the document.
  ///
  /// Appending is the only deterministic insertion this editor performs: it
  /// keeps every existing section, its order and its index unchanged, so a
  /// section index recorded before the append still refers to the same
  /// section afterwards.
  RawChkDocument appendSection(RawChkSection section) {
    return RawChkDocument(
      sections: [...sections, section],
      sourceLength: sourceLength,
    );
  }

  /// Removes [count] sections from the end of the document, undoing the same
  /// number of [appendSection] calls.
  RawChkDocument removeTrailingSections(int count) {
    if (count < 0 || count > sections.length) {
      throw RangeError.range(count, 0, sections.length, 'count');
    }
    if (count == 0) {
      return this;
    }
    return RawChkDocument(
      sections: sections.sublist(0, sections.length - count),
      sourceLength: sourceLength,
    );
  }
}
