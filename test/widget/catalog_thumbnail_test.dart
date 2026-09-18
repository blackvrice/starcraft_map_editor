import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/presentation/placement/catalog_thumbnail.dart';

void main() {
  Widget thumbnail(
    Uint8List bytes, {
    int width = 1,
    int height = 1,
    double scale = 1,
  }) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: CatalogThumbnail(
        rgbaBytes: bytes,
        width: width,
        height: height,
        scale: scale,
      ),
    ),
  );

  Future<ui.Image> decoded(WidgetTester tester) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      final image = tester.widget<RawImage>(find.byType(RawImage)).image;
      if (image != null) return image;
    }
    throw StateError('Thumbnail did not decode within the test deadline.');
  }

  testWidgets(
    'replaces pixels and dimensions, clears invalid data and scales without decoding',
    (tester) async {
      final red = Uint8List.fromList([255, 0, 0, 255]);
      final blue = Uint8List.fromList([0, 0, 255, 255]);
      await tester.pumpWidget(thumbnail(red));
      final first = await decoded(tester);
      final firstBytes = await tester.runAsync(() => first.toByteData());
      expect(firstBytes!.buffer.asUint8List(), red);

      await tester.pumpWidget(thumbnail(blue));
      expect(first.debugDisposed, isTrue);
      final second = await decoded(tester);
      final secondBytes = await tester.runAsync(() => second.toByteData());
      expect(secondBytes!.buffer.asUint8List(), blue);

      await tester.pumpWidget(thumbnail(blue, scale: 2));
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image,
        same(second),
      );
      expect(tester.getSize(find.byType(RawImage)), const Size(2, 2));

      final twoPixels = Uint8List.fromList([...red, ...blue]);
      await tester.pumpWidget(thumbnail(twoPixels, width: 2));
      final wide = await decoded(tester);
      expect(wide.width, 2);
      expect(wide.height, 1);
      // The same buffer can be reinterpreted with new dimensions.
      await tester.pumpWidget(thumbnail(twoPixels, height: 2));
      final tall = await decoded(tester);
      expect(wide.debugDisposed, isTrue);
      expect(tall.width, 1);
      expect(tall.height, 2);

      await tester.pumpWidget(thumbnail(Uint8List(3)));
      expect(tall.debugDisposed, isTrue);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNull);
      await tester.pumpWidget(thumbnail(Uint8List(0), width: 0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid replacement and close dispose every created image handle',
    (tester) async {
      final live = <ui.Image>{};
      final oldCreate = ui.Image.onCreate;
      final oldDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        oldCreate?.call(image);
        live.add(image);
      };
      ui.Image.onDispose = (image) {
        live.remove(image);
        oldDispose?.call(image);
      };
      addTearDown(() {
        ui.Image.onCreate = oldCreate;
        ui.Image.onDispose = oldDispose;
      });
      final red = Uint8List.fromList([255, 0, 0, 255]);
      final green = Uint8List.fromList([0, 255, 0, 255]);
      await tester.pumpWidget(thumbnail(red));
      await tester.pumpWidget(thumbnail(green));
      final latest = await decoded(tester);
      final bytes = await tester.runAsync(() => latest.toByteData());
      expect(bytes!.buffer.asUint8List(), green);
      await tester.pumpWidget(thumbnail(red));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(live, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
