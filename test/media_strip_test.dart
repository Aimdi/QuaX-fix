import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/media_strip.dart';

void main() {
  group('what shape a card is allowed to be', () {
    test('an ordinary photo keeps its own', () {
      expect(clampMediaAspect(1.0), 1.0);
      expect(clampMediaAspect(1.5), 1.5);
    });

    test('a sliver is cropped to the nearest end rather than shown as one', () {
      expect(clampMediaAspect(0.2), kMediaMinAspect);
      expect(clampMediaAspect(6.0), kMediaMaxAspect);
    });

    test('a size the response did not carry is treated as square', () {
      expect(clampMediaAspect(0), 1);
      expect(clampMediaAspect(-3), 1);
      expect(clampMediaAspect(double.nan), 1);
      expect(clampMediaAspect(double.infinity), kMediaMaxAspect);
    });
  });

  group('laying media out along a row', () {
    test('one photo takes the full width and keeps its shape', () {
      final layout = mediaStripLayout(width: 400, aspects: [0.5]);

      expect(layout.widths, [400]);
      expect(layout.height, closeTo(400 / kMediaMinAspect, 0.001),
          reason: 'cropped to the tallest allowed rather than running off the screen');
    });

    test('several share one height', () {
      final layout = mediaStripLayout(width: 400, aspects: [0.8, 1.0, 1.5]);

      expect(layout.height, closeTo(400 * kMediaStripHeightFactor, 0.001));
      expect(layout.widths, hasLength(3));
    });

    // This is the whole point: how many fit is not a rule about the count, it
    // falls out of the shapes. Tall photos are narrow, so more are in view.
    test('tall photos are narrower than wide ones, so more of them fit', () {
      final tall = mediaStripLayout(width: 400, aspects: [0.8, 0.8, 0.8]);
      final wide = mediaStripLayout(width: 400, aspects: [1.91, 1.91, 1.91]);

      expect(tall.widths.first, lessThan(wide.widths.first));

      double visible(MediaStripLayout layout) {
        var used = 0.0, count = 0.0;
        for (final w in layout.widths) {
          if (used >= 400) break;
          used += w + kMediaCardGap;
          count++;
        }
        return count;
      }

      expect(visible(tall), greaterThan(visible(wide)));
    });

    test('no card fills the row, so the next one always shows an edge', () {
      final layout = mediaStripLayout(width: 400, aspects: [1.91, 1.91]);

      for (final width in layout.widths) {
        expect(width, lessThan(400));
      }
    });

    test('nothing attached lays out as nothing', () {
      final layout = mediaStripLayout(width: 400, aspects: const []);

      expect(layout.widths, isEmpty);
      expect(layout.height, 0);
    });
  });

  group('opening a post at one of its pictures', () {
    test('the first one needs no scrolling', () {
      expect(mediaStripOffsetOf(0, const [100, 100, 100]), 0);
    });

    test('a later one counts the cards and the gaps before it', () {
      expect(mediaStripOffsetOf(2, const [100, 120, 100], gap: 8), 100 + 8 + 120 + 8);
    });

    test('an index past the end stops at the last card rather than throwing', () {
      expect(mediaStripOffsetOf(9, const [100, 100], gap: 8), 100 + 8 + 100 + 8);
    });
  });
}
