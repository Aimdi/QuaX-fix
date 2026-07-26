import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/article_link_card.dart';
import 'package:quax/utils/urls.dart';

void main() {
  group('articleIdIn', () {
    test('takes the id out of an article link', () {
      expect(articleIdIn('https://x.com/i/article/2080123456789'), '2080123456789');
    });

    test('twitter.com and the www hosts count too', () {
      for (final host in ['twitter.com', 'www.x.com', 'mobile.twitter.com']) {
        expect(articleIdIn('https://$host/i/article/42'), '42', reason: host);
      }
    });

    test('a trailing slug does not confuse it', () {
      expect(articleIdIn('https://x.com/i/article/42/some-title'), '42');
    });

    test('other X links are not articles', () {
      for (final url in [
        'https://x.com/someone/status/123',
        'https://x.com/i/lists/9',
        'https://x.com/i/article',
        'https://x.com/i',
      ]) {
        expect(articleIdIn(url), isNull, reason: url);
      }
    });

    test('another site hosting the same path is not an X article', () {
      expect(articleIdIn('https://example.com/i/article/42'), isNull);
    });

    test('nothing at all is not an article', () {
      expect(articleIdIn(null), isNull);
      expect(articleIdIn(''), isNull);
      expect(articleIdIn('not a url at all ::::'), isNull);
    });
  });

  group('firstArticleLink', () {
    test('finds the article among ordinary links', () {
      final urls = ['https://example.com', 'https://x.com/i/article/7', 'https://x.com/i/article/8'];

      expect(firstArticleLink(urls), 'https://x.com/i/article/7');
    });

    test('a post with no article link has none', () {
      expect(firstArticleLink(['https://example.com', null]), isNull);
    });

    test('a post with no links at all has none', () {
      expect(firstArticleLink(const []), isNull);
    });
  });
}
