import 'package:flutter_test/flutter_test.dart';
import 'package:quax/plugins/reddit/reddit_media_urls.dart';

void main() {
  group('what a URL points at', () {
    test('a picture host serves a picture whatever the path looks like', () {
      expect(redditImageUrl('https://i.redd.it/abc'), 'https://i.redd.it/abc');
      expect(redditImageUrl('https://preview.redd.it/x?width=640'), isNotNull);
    });

    test('an image extension is enough on any host', () {
      expect(redditImageUrl('https://example.com/photo.PNG'), 'https://example.com/photo.PNG');
      expect(redditImageUrl('https://example.com/anim.gif'), isNotNull);
    });

    test("imgur's gifv is a video player; the gif beside it is the animation", () {
      expect(redditImageUrl('https://i.imgur.com/abc.gifv'), 'https://i.imgur.com/abc.gif');
    });

    test('a page is not a picture', () {
      expect(redditImageUrl('https://www.reddit.com/gallery/abc'), isNull);
      expect(redditImageUrl('https://v.redd.it/abc'), isNull);
      expect(redditImageUrl(null), isNull);
      expect(redditImageUrl('not a url at all'), isNull);
      expect(redditImageUrl('javascript:alert(1)'), isNull, reason: 'only http(s) is ever loaded');
    });

    test('video hosts are known regardless of www', () {
      expect(isRedditVideoHost('v.redd.it'), isTrue);
      expect(isRedditVideoHost('www.youtube.com'), isTrue);
      expect(isRedditVideoHost('example.com'), isFalse);
      expect(isRedditVideoHost(null), isFalse);
    });
  });
}
