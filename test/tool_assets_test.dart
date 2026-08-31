// Every tool's before/after art must actually exist and decode.
//
// [DemoImage] hands a missing or unreadable asset to `errorBuilder`, which
// quietly falls back to the procedural scene painter. That is the right
// behaviour at runtime — a mis-keyed tool shows believable art instead of a
// broken-image glyph — but it means a renamed, corrupted or wrong-format asset
// produces no error anywhere: the app just silently stops showing photography.
// Nothing else in the suite would catch it, so this does.

import 'dart:ui' as ui;

import 'package:ai_enhancer/data/catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final artKeys = <String>{
    for (final category in Catalog.allCategories)
      for (final tool in category.tools)
        if (tool.art != null) tool.art!,
  };

  test('the catalog actually declares tool art', () {
    // Guards the loop below from silently passing on an empty set.
    expect(artKeys, isNotEmpty);
  });

  group('tool art decodes', () {
    for (final key in artKeys) {
      for (final variant in const ['before', 'after']) {
        test('$key/$variant', () async {
          final path = 'assets/tools/${key}_$variant.webp';

          final ByteData data;
          try {
            data = await rootBundle.load(path);
          } catch (e) {
            fail('$path is missing from the bundle: $e');
          }
          expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');

          // Proves the bytes are a format Flutter can actually draw — a file
          // that exists but isn't decodable would still hit errorBuilder.
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          addTearDown(frame.image.dispose);
          addTearDown(codec.dispose);

          expect(frame.image.width, greaterThan(0));
          expect(frame.image.height, greaterThan(0));
        });
      }
    }
  });
}
