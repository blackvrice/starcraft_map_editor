import 'dart:convert';
import 'dart:io';

import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';

import '../test/fixtures/doodad_deletion_fixture.dart';

// Synthetic maps only. This is a local JIT measurement, not a timing gate.
void main() {
  for (final count in [1, 8, 32]) {
    final doc = largeBatchDeletionDocument(count: count);
    final requests = batchDeletionRequests(count: count);
    DoodadDeletionPlan prepare() =>
        DoodadDeletionPlan.createBatch(document: doc, requests: requests);
    for (var i = 0; i < 10; i++) {
      prepare();
    }
    final samples = <int>[];
    for (var i = 0; i < 31; i++) {
      final timer = Stopwatch()..start();
      final plan = prepare();
      timer.stop();
      if (plan.doodadCount != count || !identical(plan.document, doc)) {
        throw StateError('Invalid benchmark plan.');
      }
      samples.add(timer.elapsedMicroseconds);
    }
    samples.sort();
    stdout.writeln(
      jsonEncode({
        'map': '256x256',
        'doodads': count,
        'samples': samples.length,
        'medianUs': samples[samples.length ~/ 2],
        'p95Us': samples[(samples.length * .95).ceil() - 1],
      }),
    );
  }
}
