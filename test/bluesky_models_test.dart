import 'package:flutter_test/flutter_test.dart';
import 'package:xta/plugins/bluesky/bluesky_models.dart';

void main() {
  group('normaliseBlueskyAppView', () {
    test('accepts bare hosts and trims trailing slashes', () {
      expect(normaliseBlueskyAppView('public.api.bsky.app'), 'https://public.api.bsky.app');
      expect(normaliseBlueskyAppView('https://public.api.bsky.app/'), 'https://public.api.bsky.app');
      expect(normaliseBlueskyAppView('  https://example.org  '), 'https://example.org');
    });

    test('refuses empty or non-http values', () {
      expect(normaliseBlueskyAppView(''), isNull);
      expect(normaliseBlueskyAppView('ftp://example.org'), isNull);
      expect(normaliseBlueskyAppView('not a url'), isNull);
    });

    test('blueskyAppViewFromPrefs falls back to the working default', () {
      expect(blueskyAppViewFromPrefs(null), kBlueskyDefaultAppView);
      expect(blueskyAppViewFromPrefs(''), kBlueskyDefaultAppView);
      expect(blueskyAppViewFromPrefs('ftp://nope'), kBlueskyDefaultAppView);
      expect(blueskyAppViewFromPrefs('https://my.appview.example'), 'https://my.appview.example');
    });
  });

  group('normaliseBlueskyHandle', () {
    test('accepts bare handles, @handles and profile URLs', () {
      expect(normaliseBlueskyHandle('alice.bsky.social'), 'alice.bsky.social');
      expect(normaliseBlueskyHandle('@Alice.bsky.social'), 'alice.bsky.social');
      expect(normaliseBlueskyHandle('  @alice.bsky.social '), 'alice.bsky.social');
      expect(normaliseBlueskyHandle('https://bsky.app/profile/alice.bsky.social'), 'alice.bsky.social');
      expect(normaliseBlueskyHandle('https://www.bsky.app/profile/alice.bsky.social/post/abc'),
          'alice.bsky.social');
    });

    test('keeps dotted custom handles', () {
      expect(normaliseBlueskyHandle('jay.bsky.team'), 'jay.bsky.team');
    });

    test('accepts did:plc identifiers', () {
      expect(normaliseBlueskyHandle('did:plc:z72i7hdynmk6r22z27h6tvur'),
          'did:plc:z72i7hdynmk6r22z27h6tvur');
      expect(normaliseBlueskyHandle('DID:PLC:z72i7hdynmk6r22z27h6tvur'),
          'did:plc:z72i7hdynmk6r22z27h6tvur');
    });

    test('refuses what is not a handle', () {
      expect(normaliseBlueskyHandle(''), isNull);
      expect(normaliseBlueskyHandle('   '), isNull);
      expect(normaliseBlueskyHandle('@'), isNull);
      expect(normaliseBlueskyHandle('nodot'), isNull);
      expect(normaliseBlueskyHandle('two words.bsky.social'), isNull);
      expect(normaliseBlueskyHandle('https://example.org/nothing'), isNull);
      expect(normaliseBlueskyHandle('did:web:example.com'), isNull);
    });
  });

  group('blueskyWebUrl / blueskyRkeyOf', () {
    test('builds a bsky.app post URL from handle and at:// URI', () {
      expect(
        blueskyWebUrl(
          handle: 'bsky.app',
          atUri: 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3mqafridzgk2e',
        ),
        'https://bsky.app/profile/bsky.app/post/3mqafridzgk2e',
      );
    });

    test('returns null when the URI has no rkey', () {
      expect(blueskyRkeyOf('not-an-at-uri'), isNull);
      expect(blueskyWebUrl(handle: 'bsky.app', atUri: 'at://did:plc:x/app.bsky.feed.post'), isNull);
    });
  });

  group('parseBlueskyFeed', () {
    test('reads text, author, images and date off a feed item', () {
      final posts = parseBlueskyFeed({
        'feed': [
          {
            'post': {
              'uri': 'at://did:plc:abc/app.bsky.feed.post/rkey1',
              'cid': 'bafyreiabc',
              'author': {
                'did': 'did:plc:abc',
                'handle': 'alice.bsky.social',
                'displayName': 'Alice',
                'avatar': 'https://example.org/a.jpg',
              },
              'record': {
                '\$type': 'app.bsky.feed.post',
                'text': 'Hello from Bluesky',
                'createdAt': '2026-08-01T09:00:00.000Z',
              },
              'embed': {
                '\$type': 'app.bsky.embed.images#view',
                'images': [
                  {
                    'thumb': 'https://example.org/thumb.jpg',
                    'fullsize': 'https://example.org/full.jpg',
                  }
                ],
              },
            },
          },
        ],
      });

      expect(posts, hasLength(1));
      final post = posts.first;
      expect(post.text, 'Hello from Bluesky');
      expect(post.handle, 'alice.bsky.social');
      expect(post.did, 'did:plc:abc');
      expect(post.authorName, 'Alice');
      expect(post.images, ['https://example.org/thumb.jpg']);
      expect(post.url, 'https://bsky.app/profile/alice.bsky.social/post/rkey1');
      expect(post.publishedAt, isNotNull);
    });

    test('drops empty items and tolerates a reshaped feed', () {
      expect(parseBlueskyFeed(null), isEmpty);
      expect(parseBlueskyFeed({'feed': 'nope'}), isEmpty);
      expect(
        parseBlueskyFeed({
          'feed': [
            {
              'post': {
                'uri': 'at://did:plc:abc/app.bsky.feed.post/empty',
                'author': {'handle': 'alice.bsky.social'},
                'record': {'text': '   '},
              },
            },
          ],
        }),
        isEmpty,
      );
    });
  });

  group('BlueskyProfile.fromJson', () {
    test('reads documented fields defensively', () {
      final profile = BlueskyProfile.fromJson({
        'did': 'did:plc:abc',
        'handle': 'alice.bsky.social',
        'displayName': 'Alice',
        'avatar': 'https://example.org/a.jpg',
        'description': 'Hi',
        'followersCount': 12,
        'followsCount': 3,
        'postsCount': 40,
      });

      expect(profile.did, 'did:plc:abc');
      expect(profile.handle, 'alice.bsky.social');
      expect(profile.displayName, 'Alice');
      expect(profile.followersCount, 12);
      expect(profile.toAccount().actor, 'did:plc:abc');
    });
  });
}
