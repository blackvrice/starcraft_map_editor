import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';

import '../test/fixtures/localization_fixture.dart';

/// Runs with the Windows engine to check real font fallback, not tester fonts.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  FlutterError.onError = (details) => errors.add(details.toString());
  final fixture = LocalizationFixture();
  final directory = Directory('.dart_tool/localization_windows_smoke');
  await directory.create(recursive: true);
  for (final width in [600.0, 1000.0]) {
    for (final screen in fixture.screens) {
      final boundary = GlobalKey();
      runApp(
        MaterialApp(
          key: ValueKey('${screen.name}-$width'),
          debugShowCheckedModeBanner: false,
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Center(
            child: OverflowBox(
              maxWidth: width,
              maxHeight: 900,
              minWidth: width,
              minHeight: 900,
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: width,
                  height: 900,
                  child: Scaffold(body: screen.widget),
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await WidgetsBinding.instance.endOfFrame;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${directory.path}/${screen.name}-${width.toInt()}.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }
  }
  runApp(const SizedBox.shrink());
  await WidgetsBinding.instance.endOfFrame;
  await fixture.dispose();
  await File(
    '${directory.path}/render_errors.txt',
  ).writeAsString(errors.join('\n'));
  exit(errors.isEmpty ? 0 : 1);
}
