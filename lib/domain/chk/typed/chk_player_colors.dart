import '../raw_chk_document.dart';
import '../raw_chk_section.dart';
import 'chk_metadata_views.dart';

final class ChkPlayerColor {
  const ChkPlayerColor(this.mode, this.red, this.green, this.blue);
  final int mode, red, green, blue;
  static const palette = <int>[
    0xfff40404,
    0xff0c48cc,
    0xff2cb494,
    0xff88409c,
    0xfff88c14,
    0xff703014,
    0xffcce0d0,
    0xfffcfc38,
    0xff088008,
    0xfffcfc7c,
    0xffecc4b0,
    0xff4068d4,
  ];
  int? get argb => [red, green, blue].any((v) => v < 0 || v > 255)
      ? null
      : switch (mode) {
          2 => 0xff000000 | red << 16 | green << 8 | blue,
          3 => blue < palette.length ? palette[blue] : null,
          _ => null,
        };
}

/// CRGB is 8 RGB triples followed by 8 mode bytes. CRGB takes precedence
/// for this editor; COLR is retained as the legacy fallback, never synthesized.
abstract final class ChkPlayerColors {
  static List<ChkPlayerColor> read(RawChkDocument doc) {
    final rgb = doc.sections.where((s) => s.name == 'CRGB').toList();
    if (rgb.isNotEmpty) {
      if (rgb.length != 1 || rgb.single.payload.length != 32) {
        throw const FormatException('Expected one 32-byte CRGB section.');
      }
      final b = rgb.single.payload;
      return List.unmodifiable([
        for (var i = 0; i < 8; i++)
          ChkPlayerColor(b[24 + i], b[i * 3], b[i * 3 + 1], b[i * 3 + 2]),
      ]);
    }
    final colr = doc.sections.where((s) => s.name == 'COLR').toList();
    if (colr.length != 1 || colr.single.payload.length != 8) {
      throw const FormatException('Expected one 8-byte COLR section.');
    }
    return List.unmodifiable([
      for (final id in colr.single.payload) ChkPlayerColor(3, 0, 0, id),
    ]);
  }

  static RawChkDocument edit(
    RawChkDocument doc,
    Map<int, ChkPlayerColor> changes,
  ) {
    if (changes.isEmpty) return doc;
    final versions = const ChkMetadataViewDecoder().decode(doc).versions;
    if (versions.length != 1 ||
        ![205, 206].contains(versions.single.knownVersion?.rawValue) ||
        doc.sections.where((s) => s.name == 'VER ').length != 1) {
      throw const FormatException(
        'Remastered colors require one Brood War or Remastered VER section.',
      );
    }
    final previous = read(doc);
    final index = doc.sections.indexWhere((s) => s.name == 'CRGB');
    final bytes = index < 0
        ? List<int>.filled(32, 0)
        : doc.sections[index].payload.toList();
    if (index < 0) {
      for (var p = 0; p < 8; p++) {
        bytes[p * 3 + 2] = previous[p].blue;
        bytes[24 + p] = 3;
      }
    }
    var changed = index < 0;
    for (final entry in changes.entries) {
      final p = entry.key, c = entry.value;
      RangeError.checkValueInInterval(p, 0, 7, 'player');
      final old = previous[p];
      if (old.mode == c.mode &&
          old.red == c.red &&
          old.green == c.green &&
          old.blue == c.blue) {
        continue;
      }
      if (c.mode < 0 ||
          c.mode > 3 ||
          [c.red, c.green, c.blue].any((v) => v < 0 || v > 255)) {
        throw const FormatException('Invalid CRGB value.');
      }
      if (c.mode == 3 &&
          c.blue > 11 &&
          !(old.mode == 3 && c.blue == old.blue)) {
        throw const FormatException('Unsupported palette ID.');
      }
      bytes.setRange(p * 3, p * 3 + 3, [c.red, c.green, c.blue]);
      bytes[24 + p] = c.mode;
      changed = true;
    }
    if (!changed) return doc;
    if (index < 0) {
      doc = doc.appendSection(
        RawChkSection(
          nameBytes: 'CRGB'.codeUnits,
          declaredLength: 32,
          payload: bytes,
          sourceOffset: doc.sourceLength,
          isDirty: true,
        ),
      );
    } else {
      doc = doc.replaceSection(index, doc.sections[index].withPayload(bytes));
    }
    // Entering Remastered colors is explicit; preserve every other VER byte.
    final versionIndex = doc.sections.indexWhere((s) => s.name == 'VER ');
    if (versions.single.knownVersion!.rawValue == 205) {
      final v = doc.sections[versionIndex].payload.toList()..[0] = 206;
      doc = doc.replaceSection(
        versionIndex,
        doc.sections[versionIndex].withPayload(v),
      );
    }
    return doc;
  }

  static int? preview(RawChkDocument doc, int owner) {
    if (owner < 0 || owner >= 8) return null;
    try {
      return read(doc)[owner].argb;
    } on FormatException {
      return null;
    }
  }
}
