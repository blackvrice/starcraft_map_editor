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
}
