import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pref/pref.dart';
import 'package:xta/constants.dart';
import 'package:xta/plugins/threads/threads_client.dart';
import 'package:xta/plugins/threads/threads_direct_client.dart';

void main() {
  group('parseThreadsCookieHeader', () {
    test('splits a Cookie header into a map', () {
      final cookies = parseThreadsCookieHeader(
        'sessionid=abc%3A1; csrftoken=tok; ds_user_id=9; mid=m; ig_did=uuid; other=x',
      );
      expect(cookies['sessionid'], 'abc%3A1');
      expect(cookies['csrftoken'], 'tok');
      expect(cookies['ds_user_id'], '9');
      expect(threadsCookiesComplete(cookies), isTrue);
    });

    test('rejects incomplete cookies', () {
      expect(threadsCookiesComplete({'sessionid': 'x'}), isFalse);
    });
  });

  group('normaliseThreadsBearer', () {
    test('accepts IGT:2 with or without Bearer prefix', () {
      expect(normaliseThreadsBearer('IGT:2:abc'), 'IGT:2:abc');
      expect(normaliseThreadsBearer('Bearer IGT:2:abc'), 'IGT:2:abc');
      expect(normaliseThreadsBearer('not-a-token'), isNull);
    });
  });

  group('parseThreadsApiFeed', () {
    test('reads caption, user and permalink from thread_items', () {
      final posts = parseThreadsApiFeed({
        'threads': [
          {
            'thread_items': [
              {
                'post': {
                  'pk': '111',
                  'code': 'AbC',
                  'taken_at': 1720000000,
                  'caption': {'text': 'Hello Threads'},
                  'user': {
                    'username': 'zuck',
                    'full_name': 'Mark',
                    'profile_pic_url': 'https://example.org/a.jpg',
                  },
                  'image_versions2': {
                    'candidates': [
                      {'url': 'https://example.org/p.jpg'},
                    ],
                  },
                },
              },
            ],
          },
        ],
      });

      expect(posts, hasLength(1));
      expect(posts.first.text, 'Hello Threads');
      expect(posts.first.handle, 'zuck');
      expect(posts.first.authorName, 'Mark');
      expect(posts.first.url, 'https://www.threads.com/@zuck/post/AbC');
      expect(posts.first.images, ['https://example.org/p.jpg']);
      expect(posts.first.publishedAt, isNotNull);
    });
  });

  group('parseThreadsSsrHtml', () {
    test('pulls posts out of data-sjs blobs', () {
      final blob = jsonEncode({
        'require': [
          [
            'RelayPrefetchedStreamCache',
            'next',
            [
              null,
              {
                'thread_items': [
                  {
                    'post': {
                      'pk': '9',
                      'code': 'Xx',
                      'caption': {'text': 'from ssr'},
                      'user': {'username': 'zuck', 'full_name': 'Z'},
                    },
                  },
                ],
              },
            ],
          ],
        ],
      });
      final html = '<html><script type="application/json" data-sjs>$blob</script></html>';
      final posts = parseThreadsSsrHtml(html, 'zuck');
      expect(posts, hasLength(1));
      expect(posts.first.text, 'from ssr');
    });
  });

  group('ThreadsDirectClient', () {
    late PrefServiceCache prefs;

    setUp(() {
      prefs = PrefServiceCache(cache: {
        optionPluginThreadsDirectCookies: '',
        optionPluginThreadsDirectBearer: '',
        optionPluginThreadsDirectDeviceId: 'device-1',
      });
    });

    test('fetchFollowingTimeline sends Bearer to Instagram API', () async {
      await prefs.set(optionPluginThreadsDirectBearer, 'IGT:2:secret');
      final client = ThreadsDirectClient(
        prefs,
        minGap: Duration.zero,
        httpClient: MockClient((request) async {
          expect(request.url.host, 'i.instagram.com');
          expect(request.url.path, '/api/v1/feed/text_post_app_timeline/');
          expect(request.url.queryParameters['pagination_source'], 'text_post_feed_following');
          expect(request.headers['Authorization'], 'Bearer IGT:2:secret');
          return http.Response(
            jsonEncode({
              'threads': [
                {
                  'thread_items': [
                    {
                      'post': {
                        'pk': '1',
                        'code': 'c',
                        'caption': {'text': 'hi'},
                        'user': {'username': 'a', 'full_name': 'A'},
                      },
                    },
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final posts = await client.fetchFollowingTimeline();
      expect(posts.first.text, 'hi');
    });

    test('maps login_required to sessionSuspended', () async {
      await prefs.set(
        optionPluginThreadsDirectCookies,
        'sessionid=s; csrftoken=c; ds_user_id=1; mid=m; ig_did=g',
      );
      final client = ThreadsDirectClient(
        prefs,
        minGap: Duration.zero,
        httpClient: MockClient(
          (_) async => http.Response('{"message":"login_required","logout_reason":8}', 403),
        ),
      );

      expect(
        () => client.currentUser(),
        throwsA(isA<ThreadsException>().having((e) => e.kind, 'kind', ThreadsErrorKind.sessionSuspended)),
      );
    });
  });
}
