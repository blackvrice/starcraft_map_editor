import 'dart:convert';
import 'dart:io';

/// Summarizes comparable fresh-process runs, preserving every input observation.
Map<String, Object?> summarizeCatalogProfile(List<Map<String, dynamic>> runs) {
  if (runs.length < 3) {
    throw const FormatException('At least three profile runs are required.');
  }
  const environment = [
    'mode',
    'fixture',
    'os',
    'dart',
    'physicalWidth',
    'physicalHeight',
    'devicePixelRatio',
  ];
  const metrics = [
    'firstImageMs',
    'searchMs',
    'scroll12Ms',
    'buildP95Us',
    'rasterP95Us',
    'builtItems',
    'loadedEntries',
    'retainedRgbaBytes',
    'peakImageHandles',
    'liveImageHandlesAfterClose',
    'frameCount',
  ];
  for (var i = 0; i < runs.length; i++) {
    final run = runs[i];
    void reject(String reason) =>
        throw FormatException('Run ${i + 1}: $reason');
    if (run['passed'] != true || run['mode'] != 'profile') {
      reject('requires a successful profile run');
    }
    for (final key in environment) {
      final value = run[key];
      if (value == null || value != runs.first[key]) {
        reject('missing or mismatched $key');
      }
      if (key == 'physicalWidth' ||
          key == 'physicalHeight' ||
          key == 'devicePixelRatio') {
        if (value is! num || !value.isFinite || value <= 0) {
          reject('invalid $key');
        }
      } else if (value is! String || value.isEmpty) {
        reject('invalid $key');
      }
    }
    for (final key in metrics) {
      final value = run[key];
      if (value is! int || value < 0) reject('invalid $key');
    }
    if ((run['builtItems'] as int) == 0 ||
        (run['builtItems'] as int) >= 128 ||
        (run['loadedEntries'] as int) <= 256 ||
        (run['frameCount'] as int) == 0 ||
        run['liveImageHandlesAfterClose'] != 0) {
      reject('virtualization, paging, frame, or image cleanup check failed');
    }
  }
  final summary = <String, Object?>{};
  for (final key in metrics) {
    final values = runs.map((run) => run[key] as int).toList()..sort();
    final middle = values.length ~/ 2;
    summary[key] = {
      'min': values.first,
      'median': values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) / 2,
      'max': values.last,
    };
  }
  return {
    'runCount': runs.length,
    'environment': {for (final key in environment) key: runs.first[key]},
    'metrics': summary,
    'runs': runs,
  };
}

/// Prints JSON to stdout; callers choose a new output path without overwriting.
void main(List<String> paths) {
  try {
    final identities = <String>{};
    final runs = <Map<String, dynamic>>[];
    for (final path in paths) {
      final file = File(path);
      if (!identities.add(file.resolveSymbolicLinksSync().toLowerCase())) {
        throw const FormatException('Duplicate input file.');
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Expected a JSON object: $path');
      }
      runs.add(decoded);
    }
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(summarizeCatalogProfile(runs)),
    );
  } on Object catch (error) {
    stderr.writeln('Catalog profile summary failed: $error');
    exitCode = 1;
  }
}
