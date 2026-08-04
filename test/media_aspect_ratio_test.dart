import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/_media.dart';

/// Built from API-shaped JSON, so the entities are the ones the tile is really
/// handed. A null size stands for the media entity X sometimes sends with no
/// `sizes` at all.
List<Media> _media(List<Map<String, int>?> sizes) {
  return Entities.fromJson({
    'media': [
      for (final size in sizes)
        {
          'type': 'photo',
          'media_url_https': 'https://pbs.example/photo.jpg',
          if (size != null) 'sizes': {'large': size},
        }
    ]
  }).media!;
}

void main() {
  group('mediaFrameAspectRatio', () {
    test('a single photo keeps its own shape', () {
      final ratio = mediaFrameAspectRatio(_media([
        {'w': 1200, 'h': 675}
      ]));

      expect(ratio, closeTo(1200 / 675, 0.0001));
    });

    test('the tallest item sets the frame, so no page is cropped', () {
      final ratio = mediaFrameAspectRatio(_media([
        {'w': 1200, 'h': 675},
        {'w': 1000, 'h': 1000},
      ]));

      expect(ratio, closeTo(1.0, 0.0001));
    });

    test('one very tall screenshot cannot stretch the whole carousel', () {
      // 1080x2400 is 0.45 — laid out unbounded, the three landscape photos
      // beside it render inside enormous empty bands and the post's footer is
      // pushed off screen.
      final ratio = mediaFrameAspectRatio(_media([
        {'w': 1200, 'h': 675},
        {'w': 1200, 'h': 675},
        {'w': 1200, 'h': 675},
        {'w': 1080, 'h': 2400},
      ]));

      expect(ratio, closeTo(kMediaFrameMinAspectRatio, 0.0001));
    });

    test('an ordinary portrait photo is left alone', () {
      final ratio = mediaFrameAspectRatio(_media([
        {'w': 1080, 'h': 1350}
      ]));

      expect(ratio, closeTo(1080 / 1350, 0.0001), reason: '4:5 is taller than wide but not extreme');
    });

    test('media with no sizes falls back instead of failing the tile', () {
      expect(mediaFrameAspectRatio(_media([null])), kMediaFrameFallbackAspectRatio);
      expect(mediaFrameAspectRatio(const []), kMediaFrameFallbackAspectRatio);
    });

    test('a degenerate size is ignored rather than producing infinity', () {
      final ratio = mediaFrameAspectRatio(_media([
        {'w': 1200, 'h': 0},
        {'w': 1200, 'h': 675},
      ]));

      expect(ratio, closeTo(1200 / 675, 0.0001));
    });

    test('every item degenerate still yields a usable frame', () {
      final ratio = mediaFrameAspectRatio(_media([
        {'w': 0, 'h': 0}
      ]));

      expect(ratio.isFinite, isTrue);
      expect(ratio, kMediaFrameFallbackAspectRatio);
    });
  });
}
