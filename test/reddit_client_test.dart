import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _tokenBody({int expiresIn = 3600}) =>
    {'access_token': 'tok_123', 'token_type': 'bearer', 'expires_in': expiresIn, 'scope': '*'};

Map<String, dynamic> _listingBody({String? after, List<Map<String, dynamic>>? children}) => {
      'kind': 'Listing',
      'data': {
        'after': after,
        'children': children ??
            [
              {
                'kind': 't3',
                'data': {
                  'id': 'abc123',
                  'title': 'Dart 4 is out',
                  'subreddit': 'dartlang',
                  'author': 'someone',
                  'score': 412,
                  'num_comments': 37,
                  'created_utc': 1769000000,
                  'permalink': '/r/dartlang/comments/abc123/dart_4_is_out/',
                  'url': 'https://dart.dev/blog',
                  'is_self': false,
                  'over_18': false,
                  'stickied': false,
                  'thumbnail': 'https://b.thumbs.redditmedia.com/x.jpg',
                },
              },
            ],
      },
    };

void main() {
  group('normaliseSubreddit', () {
    test('accepts the shapes people paste', () {
      for (final input in ['dartlang', 'r/dartlang', '/r/dartlang', '/r/dartlang/', 'R/dartlang']) {
        expect(normaliseSubreddit(input), 'dartlang', reason: input);
      }
    });

    test('pulls the name out of a URL', () {
      expect(normaliseSubreddit('https://www.reddit.com/r/dartlang/'), 'dartlang');
      expect(normaliseSubreddit('https://old.reddit.com/r/dartlang/comments/abc/x/'), 'dartlang');
    });

    test('rejects what is not a subreddit', () {
      for (final input in ['', '   ', 'a', 'has spaces', 'https://reddit.com/u/someone', 'r/', 'way_too_long_subreddit_name_here']) {
        expect(normaliseSubreddit(input), isNull, reason: input);
      }
    });
  });

  group('authorisation', () {
    test('uses the installed_client grant with the client id as basic auth', () async {
      final requests = <http.Request>[];
      final client = RedditClient(httpClient: MockClient((request) async {
        requests.add(request);
        return request.url.path.contains('access_token') ? _json(_tokenBody(), 200) : _json(_listingBody(), 200);
      }));

      await client.fetchSubreddit('dartlang', clientId: 'my_client_id');

      final token = requests.first;
      expect(token.url, Uri.parse('https://www.reddit.com/api/v1/access_token'));
      expect(token.body, contains('grant_type=https://oauth.reddit.com/grants/installed_client'));
      expect(token.body, contains('device_id=${RedditClient.deviceId}'));
      expect(token.headers['Authorization'], 'Basic ${base64Encode(utf8.encode('my_client_id:'))}');
      expect(token.headers['User-Agent'], RedditClient.userAgent);
    });

    test('reuses the token for a second request instead of re-authorising', () async {
      var tokenCalls = 0;
      final client = RedditClient(httpClient: MockClient((request) async {
        if (request.url.path.contains('access_token')) {
          tokenCalls++;
          return _json(_tokenBody(), 200);
        }
        return _json(_listingBody(), 200);
      }));

      await client.fetchSubreddit('dartlang', clientId: 'id');
      await client.fetchSubreddit('flutterdev', clientId: 'id');

      expect(tokenCalls, 1);
      expect(client.hasToken, isTrue);
    });

    test('a token that is about to expire is not reused', () async {
      var tokenCalls = 0;
      final client = RedditClient(
        clock: () => DateTime.utc(2026, 7, 25, 12),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('access_token')) {
            tokenCalls++;
            // Shorter than the safety margin, so it counts as already expired.
            return _json(_tokenBody(expiresIn: 30), 200);
          }
          return _json(_listingBody(), 200);
        }),
      );

      await client.fetchSubreddit('dartlang', clientId: 'id');
      await client.fetchSubreddit('dartlang', clientId: 'id');

      expect(tokenCalls, 2);
      expect(client.hasToken, isFalse);
    });

    // Without a client id the reader used to fail every request. It now reads
    // the public endpoint, which takes no credentials, so switching the plugin
    // on is enough to see posts.
    test('no client id reads the public endpoint, with no token and no auth header', () async {
      final requested = <http.Request>[];
      final client = RedditClient(httpClient: MockClient((request) async {
        requested.add(request);
        return _json(_listingBody(), 200);
      }));

      final listing = await client.fetchSubreddit('dartlang', clientId: '  ');

      expect(requested, hasLength(1), reason: 'no token request, just the listing');
      expect(requested.single.url.host, 'www.reddit.com');
      expect(requested.single.url.path, '/r/dartlang/hot.json');
      expect(requested.single.headers.containsKey('Authorization'), isFalse);
      expect(requested.single.headers['User-Agent'], RedditClient.userAgent);
      expect(listing.posts, isNotEmpty);
    });

    test('an anonymous reader that Reddit refuses is told to set a client id', () async {
      for (final status in [403, 429]) {
        final client = RedditClient(httpClient: MockClient((_) async => _json({'error': status}, status)));

        await expectLater(
          client.fetchSubreddit('dartlang', clientId: ''),
          throwsA(isA<RedditException>().having((e) => e.kind, 'kind', RedditErrorKind.notConfigured)),
          reason: 'HTTP $status',
        );
      }
    });

    // www refusing an anonymous reader does not mean old. will: the two are
    // served and throttled separately.
    test('a refusal from www is retried against old.reddit.com', () async {
      final hosts = <String>[];
      final client = RedditClient(httpClient: MockClient((request) async {
        hosts.add(request.url.host);
        if (request.url.host == 'www.reddit.com') {
          return _json({'error': 403}, 403);
        }
        return _json(_listingBody(), 200);
      }));

      final listing = await client.fetchSubreddit('dartlang', clientId: '');

      expect(hosts, ['www.reddit.com', 'old.reddit.com']);
      expect(listing.posts, isNotEmpty);
    });

    test('a working www is not retried, so the extra request is only paid on failure', () async {
      final hosts = <String>[];
      final client = RedditClient(httpClient: MockClient((request) async {
        hosts.add(request.url.host);
        return _json(_listingBody(), 200);
      }));

      await client.fetchSubreddit('dartlang', clientId: '');

      expect(hosts, ['www.reddit.com']);
    });

    test('both public hosts refusing is reported as a block, not as missing setup', () async {
      // It used to say "add a client id". Reddit now turns away nearly every
      // new app registration, so that sent readers somewhere they could not
      // get to for a refusal that usually passes on its own.
      final client = RedditClient(httpClient: MockClient((_) async => _json({'error': 403}, 403)));

      await expectLater(
        client.fetchSubreddit('dartlang', clientId: ''),
        throwsA(isA<RedditException>()
            .having((e) => e.kind, 'kind', RedditErrorKind.blocked)
            .having((e) => e.detail, 'detail', contains('both public hosts'))),
      );
    });

    test('both public hosts throttling is reported as rate limiting', () async {
      final client = RedditClient(httpClient: MockClient((_) async => _json({'error': 429}, 429)));

      await expectLater(
        client.fetchSubreddit('dartlang', clientId: ''),
        throwsA(isA<RedditException>().having((e) => e.kind, 'kind', RedditErrorKind.rateLimited)),
      );
    });

    test('the public hosts are asked as a browser, not as an app', () async {
      // The website sits behind an edge that turns away anything announcing
      // itself as a bot, which the API-format agent does.
      final agents = <String?>[];
      final client = RedditClient(httpClient: MockClient((request) async {
        agents.add(request.headers['User-Agent']);
        return _json({
          'kind': 'Listing',
          'data': {'after': null, 'children': const []},
        }, 200);
      }));

      await client.fetchSubreddit('dartlang', clientId: '');

      expect(agents.single, RedditClient.publicUserAgent);
      expect(agents.single, startsWith('Mozilla/'));
      expect(agents.single, isNot(RedditClient.userAgent));
    });

    test('the API keeps the agent Reddit asks its clients for', () async {
      final agents = <String?>[];
      final client = RedditClient(httpClient: MockClient((request) async {
        agents.add(request.headers['User-Agent']);
        if (request.url.path.contains('access_token')) {
          return _json({'access_token': 'tok', 'expires_in': 3600}, 200);
        }
        return _json({
          'kind': 'Listing',
          'data': {'after': null, 'children': const []},
        }, 200);
      }));

      await client.fetchSubreddit('dartlang', clientId: 'my_id');

      expect(agents, everyElement(RedditClient.userAgent));
    });

    test('a 404 is not retried: the subreddit is simply not there', () async {
      final hosts = <String>[];
      final client = RedditClient(httpClient: MockClient((request) async {
        hosts.add(request.url.host);
        return _json({'error': 404}, 404);
      }));

      await expectLater(
        client.fetchSubreddit('dartlang', clientId: ''),
        throwsA(isA<RedditException>().having((e) => e.kind, 'kind', RedditErrorKind.notFound)),
      );
      expect(hosts, ['www.reddit.com']);
    });

    test('a client id still uses the authenticated host', () async {
      final requested = <http.Request>[];
      final client = RedditClient(httpClient: MockClient((request) async {
        requested.add(request);
        return _json(request.url.path.contains('access_token') ? _tokenBody() : _listingBody(), 200);
      }));

      await client.fetchSubreddit('dartlang', clientId: 'id');

      expect(requested.last.url.host, 'oauth.reddit.com');
      expect(requested.last.headers['Authorization'], startsWith('Bearer '));
    });

    test('a rejected client id is reported as unauthorised', () async {
      final client = RedditClient(httpClient: MockClient((_) async => _json({'error': 401}, 401)));

      await expectLater(
        client.verify(clientId: 'wrong'),
        throwsA(isA<RedditException>().having((e) => e.kind, 'kind', RedditErrorKind.unauthorized)),
      );
    });
  });

  group('fetchSubreddit', () {
    test('asks for the sort, limit and raw_json, and reads the listing', () async {
      Uri? listingUrl;
      final client = RedditClient(httpClient: MockClient((request) async {
        if (request.url.path.contains('access_token')) return _json(_tokenBody(), 200);
        listingUrl = request.url;
        return _json(_listingBody(after: 't3_abc123'), 200);
      }));

      final listing = await client.fetchSubreddit('r/dartlang', clientId: 'id', sort: RedditSort.newest, limit: 10);

      expect(listingUrl!.host, 'oauth.reddit.com');
      expect(listingUrl!.path, '/r/dartlang/new');
      expect(listingUrl!.queryParameters['limit'], '10');
      expect(listingUrl!.queryParameters['raw_json'], '1');

      expect(listing.after, 't3_abc123');
      final post = listing.posts.single;
      expect(post.id, 'abc123');
      expect(post.title, 'Dart 4 is out');
      expect(post.subreddit, 'dartlang');
      expect(post.score, 412);
      expect(post.commentCount, 37);
      expect(post.createdAt, isNotNull);
      expect(post.thumbnailUrl, 'https://b.thumbs.redditmedia.com/x.jpg');
    });

    test('passes the cursor on for the next page', () async {
      Uri? listingUrl;
      final client = RedditClient(httpClient: MockClient((request) async {
        if (request.url.path.contains('access_token')) return _json(_tokenBody(), 200);
        listingUrl = request.url;
        return _json(_listingBody(), 200);
      }));

      await client.fetchSubreddit('dartlang', clientId: 'id', after: 't3_abc123');

      expect(listingUrl!.queryParameters['after'], 't3_abc123');
    });

    test('a null after means the end of the listing', () async {
      final client = RedditClient(httpClient: MockClient((request) async {
        if (request.url.path.contains('access_token')) return _json(_tokenBody(), 200);
        return _json(_listingBody(after: null), 200);
      }));

      expect((await client.fetchSubreddit('dartlang', clientId: 'id')).after, isNull);
    });

    test('skips children that are not posts, and posts without a title', () async {
      final client = RedditClient(httpClient: MockClient((request) async {
        if (request.url.path.contains('access_token')) return _json(_tokenBody(), 200);
        return _json(
          _listingBody(children: [
            {'kind': 't1', 'data': {'id': 'comment'}},
            {'kind': 't3', 'data': {'id': 'no_title'}},
            {'kind': 't3', 'data': {'id': 'ok', 'title': 'Fine', 'subreddit': 'x', 'permalink': '/x'}},
          ]),
          200,
        );
      }));

      final listing = await client.fetchSubreddit('dartlang', clientId: 'id');

      expect(listing.posts.map((p) => p.id), ['ok']);
    });

    test('a self post carries its text and no thumbnail', () async {
      final client = RedditClient(httpClient: MockClient((request) async {
        if (request.url.path.contains('access_token')) return _json(_tokenBody(), 200);
        return _json(
          _listingBody(children: [
            {
              'kind': 't3',
              'data': {
                'id': 's1',
                'title': 'Ask anything',
                'subreddit': 'dartlang',
                'permalink': '/r/dartlang/comments/s1/x/',
                'is_self': true,
                'selftext': '  Some body text  ',
                'thumbnail': 'self',
                'over_18': true,
              },
            },
          ]),
          200,
        );
      }));

      final post = (await client.fetchSubreddit('dartlang', clientId: 'id')).posts.single;

      expect(post.isSelf, isTrue);
      expect(post.selfText, 'Some body text');
      expect(post.thumbnailUrl, isNull, reason: '"self" is a sentinel, not an image');
      expect(post.over18, isTrue);
    });

    test('an unknown subreddit name never leaves the device', () async {
      var called = false;
      final client = RedditClient(httpClient: MockClient((_) async {
        called = true;
        return _json(_tokenBody(), 200);
      }));

      await expectLater(
        client.fetchSubreddit('not a subreddit', clientId: 'id'),
        throwsA(isA<RedditException>().having((e) => e.kind, 'kind', RedditErrorKind.notFound)),
      );
      expect(called, isFalse);
    });

    test('each documented status maps to its own kind', () async {
      final cases = {
        403: RedditErrorKind.blocked,
        404: RedditErrorKind.notFound,
        429: RedditErrorKind.rateLimited,
        500: RedditErrorKind.badResponse,
      };

      for (final entry in cases.entries) {
        final client = RedditClient(httpClient: MockClient((request) async {
          if (request.url.path.contains('access_token')) return _json(_tokenBody(), 200);
          return _json({'error': entry.key}, entry.key);
        }));

        await expectLater(
          client.fetchSubreddit('dartlang', clientId: 'id'),
          throwsA(isA<RedditException>().having((e) => e.kind, 'kind', entry.value)),
          reason: 'HTTP ${entry.key}',
        );
      }
    });

    test('a 401 on a listing drops the cached token so the next try re-authorises', () async {
      var tokenCalls = 0;
      var listingCalls = 0;
      final client = RedditClient(httpClient: MockClient((request) async {
        if (request.url.path.contains('access_token')) {
          tokenCalls++;
          return _json(_tokenBody(), 200);
        }
        listingCalls++;
        return listingCalls == 1 ? _json({'error': 401}, 401) : _json(_listingBody(), 200);
      }));

      await expectLater(client.fetchSubreddit('dartlang', clientId: 'id'), throwsA(isA<RedditException>()));
      expect(client.hasToken, isFalse);

      await client.fetchSubreddit('dartlang', clientId: 'id');
      expect(tokenCalls, 2);
    });

    test('HTML instead of JSON is a bad response, not a crash', () async {
      final client = RedditClient(httpClient: MockClient((request) async {
        if (request.url.path.contains('access_token')) return _json(_tokenBody(), 200);
        return http.Response('<html>blocked</html>', 200, headers: {'content-type': 'text/html'});
      }));

      await expectLater(
        client.fetchSubreddit('dartlang', clientId: 'id'),
        throwsA(isA<RedditException>().having((e) => e.kind, 'kind', RedditErrorKind.badResponse)),
      );
    });

    test('an unreachable host is a network failure', () async {
      final client = RedditClient(httpClient: MockClient((_) async => throw http.ClientException('no route')));

      await expectLater(
        client.fetchSubreddit('dartlang', clientId: 'id'),
        throwsA(isA<RedditException>().having((e) => e.kind, 'kind', RedditErrorKind.network)),
      );
    });
  });
}
