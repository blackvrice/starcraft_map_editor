import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/summarize_catalog_profile.dart';

void main() {
  Map<String, dynamic> sample() =>
      jsonDecode(
            File(
              'docs/performance/catalog-profile-2026-09-20.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('reports min, median, max without discarding slow runs', () {
    final runs = [
      sample()..['searchMs'] = 90,
      sample()..['searchMs'] = 10,
      sample()..['searchMs'] = 20,
    ];
    final summary = summarizeCatalogProfile(runs);
    expect((summary['metrics'] as Map)['searchMs'], {
      'min': 10,
      'median': 20,
      'max': 90,
    });
    expect(summary['runs'], runs);
    expect(summary['runCount'], 3);
    final even = summarizeCatalogProfile([
      ...runs,
      sample()..['searchMs'] = 30,
    ]);
    expect((even['metrics'] as Map)['searchMs']['median'], 25);
  });

  test('requires at least three observations', () {
    expect(
      () => summarizeCatalogProfile([sample(), sample()]),
      throwsFormatException,
    );
  });

  for (final mutation in <String, Object?>{
    'passed': false,
    'mode': 'debug',
    'physicalWidth': 800,
    'devicePixelRatio': 1.5,
    'dart': 'another SDK',
    'fixture': 'another fixture',
    'searchMs': -1,
    'buildP95Us': null,
    'rasterP95Us': 1.5,
    'builtItems': 128,
    'loadedEntries': 256,
    'frameCount': 0,
    'liveImageHandlesAfterClose': 1,
  }.entries) {
    test('rejects invalid or incomparable ${mutation.key}', () {
      expect(
        () => summarizeCatalogProfile([
          sample(),
          sample()..[mutation.key] = mutation.value,
          sample(),
        ]),
        throwsFormatException,
      );
    });
  }
}
