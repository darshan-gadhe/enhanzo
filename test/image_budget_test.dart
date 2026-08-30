// The arithmetic that keeps every photo inside Replicate's GPU budget.
//
// The live failure this exists to stop, in the model's own words:
//
//   Input image of dimensions (1536, 1536, 4) has a total number of pixels
//   2359296 greater than the max size that fits in GPU memory on this
//   hardware, 2096704. Resize input image and try again.
//
// No files, no decoding, no engine — just the rule.

import 'package:ai_enhancer/data/image_budget.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every fitted size must satisfy all three parts of the budget.
void expectWithinBudget(ImageSize size) {
  expect(size.width, greaterThan(0));
  expect(size.height, greaterThan(0));
  expect(
    size.pixelCount,
    lessThanOrEqualTo(ImageBudget.maxSafePixels),
    reason: '$size is ${size.pixelCount} px, over the budget',
  );
  expect(size.longestEdge, lessThanOrEqualTo(ImageBudget.maxSourceEdge));
  expect(ImageBudget.isWithinBudget(size.width, size.height), isTrue);
}

/// Downscaling must not reshape the photo. One pixel of rounding on each edge
/// is the most a whole-pixel raster can avoid.
void expectSameShape(int w, int h, ImageSize fitted) {
  final before = w / h;
  final after = fitted.width / fitted.height;
  final tolerance = before * 0.01 + 1 / fitted.height;
  expect(
    after,
    closeTo(before, tolerance),
    reason: 'aspect ratio drifted: $w:$h became $fitted',
  );
}

void main() {
  group('the constants', () {
    test('the safe budget sits below the hardware ceiling, with margin', () {
      expect(ImageBudget.modelMaxPixels, 2096704);
      expect(ImageBudget.maxSafePixels, lessThan(ImageBudget.modelMaxPixels));
      // The documented derivation: 90% of what the model reported.
      expect(ImageBudget.maxSafePixels, (2096704 * 0.90).floor());
      // Still large enough to be worth enhancing — a 4:3 photo of ~1586x1190.
      expect(ImageBudget.maxSafePixels, greaterThan(1500000));
    });

    test('the hardware ceiling is the square it was reported as', () {
      expect(1448 * 1448, ImageBudget.modelMaxPixels);
    });
  });

  group('the reported failure', () {
    test('1536x1536 — the exact image the model rejected — is brought under', () {
      const w = 1536, h = 1536;
      expect(w * h, 2359296);
      expect(w * h, greaterThan(ImageBudget.modelMaxPixels));
      expect(ImageBudget.isWithinBudget(w, h), isFalse);

      final fitted = ImageBudget.fit(w, h);

      expectWithinBudget(fitted);
      expectSameShape(w, h, fitted);
      expect(fitted.width, fitted.height, reason: 'a square stays square');
      // And comfortably under the number the model actually enforces.
      expect(fitted.pixelCount, lessThan(ImageBudget.modelMaxPixels));
    });

    test('anything at all over the budget comes back under it', () {
      final size = ImageBudget.fit(1449, 1448);
      expectWithinBudget(size);
    });
  });

  group('images that already fit', () {
    test('a small photo is returned untouched', () {
      expect(ImageBudget.fit(800, 600), const ImageSize(800, 600));
      expect(ImageBudget.isWithinBudget(800, 600), isTrue);
    });

    test('an image exactly on the budget is left alone', () {
      // 1373x1374 = 1,886,502 px, just inside.
      const w = 1373, h = 1374;
      expect(w * h, lessThanOrEqualTo(ImageBudget.maxSafePixels));
      expect(ImageBudget.fit(w, h), const ImageSize(w, h));
    });

    test('never enlarges', () {
      final fitted = ImageBudget.fit(64, 48);
      expect(fitted.width, lessThanOrEqualTo(64));
      expect(fitted.height, lessThanOrEqualTo(48));
      expect(fitted, const ImageSize(64, 48));
    });
  });

  group('common shapes', () {
    // width, height, and the name to report it under.
    const cases = <(int, int, String)>[
      (4032, 3024, '4:3 phone photo'),
      (3024, 4032, '3:4 portrait phone photo'),
      (3840, 2160, '16:9 landscape'),
      (2160, 3840, '9:16 portrait'),
      (2000, 2000, 'square'),
      (6000, 4000, '35mm camera raw export'),
      (1200, 1600, 'scanned print'),
      (1536, 1536, 'the reported failure'),
    ];

    for (final (w, h, name) in cases) {
      test('$name (${w}x$h) fits, keeps its shape, and is never enlarged', () {
        final fitted = ImageBudget.fit(w, h);
        expectWithinBudget(fitted);
        expectSameShape(w, h, fitted);
        expect(fitted.width, lessThanOrEqualTo(w));
        expect(fitted.height, lessThanOrEqualTo(h));
      });
    }
  });

  group('extremes', () {
    test('a very large portrait image', () {
      const w = 4000, h = 12000;
      final fitted = ImageBudget.fit(w, h);
      expectWithinBudget(fitted);
      expectSameShape(w, h, fitted);
      expect(fitted.height, greaterThan(fitted.width));
    });

    test('a very large landscape image', () {
      const w = 12000, h = 4000;
      final fitted = ImageBudget.fit(w, h);
      expectWithinBudget(fitted);
      expectSameShape(w, h, fitted);
      expect(fitted.width, greaterThan(fitted.height));
    });

    test('an absurdly large image still resolves to something sendable', () {
      final fitted = ImageBudget.fit(30000, 20000);
      expectWithinBudget(fitted);
      expectSameShape(30000, 20000, fitted);
    });

    test('the edge cap catches a panorama the pixel cap would pass', () {
      // 8000x235 is 1,880,000 px — inside the pixel budget, absurdly wide.
      const w = 8000, h = 235;
      expect(w * h, lessThanOrEqualTo(ImageBudget.maxSafePixels));
      expect(ImageBudget.isWithinBudget(w, h), isFalse,
          reason: 'the edge cap must reject it');

      final fitted = ImageBudget.fit(w, h);
      expectWithinBudget(fitted);
      expect(fitted.width, ImageBudget.maxSourceEdge);
    });

    test('a one-pixel-tall strip stays at least one pixel tall', () {
      final fitted = ImageBudget.fit(9000, 1);
      expectWithinBudget(fitted);
      expect(fitted.height, greaterThanOrEqualTo(1));
    });
  });

  group('sizes that are not sizes', () {
    for (final (w, h) in const [(0, 100), (100, 0), (0, 0), (-1, 10)]) {
      test('${w}x$h is rejected rather than fitted', () {
        expect(() => ImageBudget.fit(w, h), throwsArgumentError);
        expect(ImageBudget.isWithinBudget(w, h), isFalse);
      });
    }
  });

  test('the guarantee holds across a wide sweep of sizes', () {
    // Nothing clever — just a lot of shapes, including the awkward ones either
    // side of both caps.
    for (var w = 1; w <= 6000; w += 137) {
      for (var h = 1; h <= 6000; h += 211) {
        final fitted = ImageBudget.fit(w, h);
        expect(fitted.pixelCount, lessThanOrEqualTo(ImageBudget.maxSafePixels),
            reason: '${w}x$h fitted to $fitted');
        expect(fitted.longestEdge,
            lessThanOrEqualTo(ImageBudget.maxSourceEdge),
            reason: '${w}x$h fitted to $fitted');
        expect(fitted.width, lessThanOrEqualTo(w));
        expect(fitted.height, lessThanOrEqualTo(h));
      }
    }
  });
}
