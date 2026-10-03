import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final layer in ['domain', 'application', 'presentation']) {
    test('$layer respects dependency and external-I/O boundaries', () {
      final violations = <String>[];
      final directives = RegExp(
        r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
        multiLine: true,
      );
      for (final file
          in Directory('lib/$layer')
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        for (final match in directives.allMatches(file.readAsStringSync())) {
          final uri = match.group(1)!;
          final externalIo = uri == 'dart:io' || uri == 'dart:ffi';
          final flutter =
              uri.startsWith('package:flutter/') ||
              uri.startsWith('package:flutter_localizations/');
          final infrastructure = uri.contains('infrastructure/');
          final upperLayer =
              uri.contains('application/') || uri.contains('presentation/');
          final binaryCodec =
              uri.endsWith('/raw_chk_parser.dart') ||
              uri.endsWith('/raw_chk_encoder.dart');
          final forbidden = switch (layer) {
            'domain' => externalIo || flutter || infrastructure || upperLayer,
            'application' =>
              externalIo ||
                  flutter ||
                  infrastructure ||
                  uri.contains('presentation/'),
            _ => externalIo || infrastructure || binaryCodec,
          };
          if (forbidden) violations.add('${file.path}: $uri');
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  }
}
