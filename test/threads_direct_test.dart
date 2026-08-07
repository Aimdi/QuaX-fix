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

  group('guest GraphQL helpers', () {
    test('extractThreadsLsd reads the LSD token blob', () {
      expect(extractThreadsLsd('nope'), isNull);
      expect(
        extractThreadsLsd(r'prefix["LSD",[],{"token":"AbC_12-x"}]suffix'),
        'AbC_12-x',
      );
    });

    test('extractThreadsUserIdFromHtml prefers pk near username', () {
      final html = r'{"username":"zuck","full_name":"Z","pk":"63055343223"}';
      expect(extractThreadsUserIdFromHtml(html, 'zuck'), '63055343223');
      expect(extractThreadsUserIdFromHtml(html, 'instagram'), isNull);
    });

    test('extractThreadsUserIdFromHtml falls back to modal userID', () {
      final html = r'{"userID":"63404918397"}{"userID":"63404918397"}{"userID":"1"}';
      expect(extractThreadsUserIdFromHtml(html, 'anyone'), '63404918397');
    });

    test('parseThreadsGraphqlFeed reads mediaData.threads', () {
      final posts = parseThreadsGraphqlFeed({
        'data': {
          'mediaData': {
            'threads': [
              {
                'thread_items': [
                  {
                    'post': {
                      'pk': '42',
                      'code': 'Cd',
                      'caption': {'text': 'from gql'},
                      'user': {'username': 'instagram', 'full_name': 'IG'},
                    },
                  },
                ],
              },
            ],
          },
        },
      });
      expect(posts, hasLength(1));
      expect(posts.first.text, 'from gql');
      expect(posts.first.handle, 'instagram');
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
          expect(request.url.queryParameters['feed_type'], 'for_you');
          expect(request.url.queryParameters['reason'], 'cold_start_fetch');
          expect(request.url.queryParameters['client_session_id'], 'device-1');
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

    test('fetchGuestAccount uses GraphQL after reading LSD and user id from HTML', () async {
      var sawGraphql = false;
      final client = ThreadsDirectClient(
        prefs,
        minGap: Duration.zero,
        httpClient: MockClient((request) async {
          if (request.method == 'GET' && request.url.path == '/@instagram') {
            return http.Response(
              r'<html><script>["LSD",[],{"token":"tok123"}]</script>'
              r'<script>{"username":"instagram","pk":"63404918397"}</script></html>',
              200,
              headers: {'content-type': 'text/html'},
            );
          }
          if (request.method == 'POST' && request.url.path == '/api/graphql') {
            sawGraphql = true;
            expect(request.headers['X-FB-LSD'], 'tok123');
            expect(request.headers['X-IG-App-ID'], '238260118697367');
            expect(request.body, contains('doc_id=$threadsGuestProfileThreadsDocId'));
            expect(request.body, contains('63404918397'));
            return http.Response(
              jsonEncode({
                'data': {
                  'mediaData': {
                    'threads': [
                      {
                        'thread_items': [
                          {
                            'post': {
                              'pk': '99',
                              'code': 'Gg',
                              'caption': {'text': 'guest gql post'},
                              'user': {'username': 'instagram', 'full_name': 'Instagram'},
                            },
                          },
                        ],
                      },
                    ],
                  },
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected ${request.method} ${request.url}', 500);
        }),
      );

      final posts = await client.fetchGuestAccount('instagram');
      expect(sawGraphql, isTrue);
      expect(posts, hasLength(1));
      expect(posts.first.text, 'guest gql post');
      expect(prefs.get<String>(optionPluginThreadsUserIds), contains('63404918397'));
    });

    test('fetchUserThreads falls back to guest GraphQL when cookies are refused', () async {
      await prefs.set(
        optionPluginThreadsDirectCookies,
        'sessionid=s; csrftoken=c; ds_user_id=1; mid=m; ig_did=g',
      );
      await prefs.set(optionPluginThreadsUserIds, '{"instagram":"63404918397"}');
      final client = ThreadsDirectClient(
        prefs,
        minGap: Duration.zero,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/text_feed/')) {
            return http.Response('{"message":"login_required","logout_reason":8}', 403);
          }
          if (request.method == 'GET' && request.url.path == '/@instagram') {
            return http.Response(
              r'<html><script>["LSD",[],{"token":"tok"}]</script>'
              r'<script>{"username":"instagram","pk":"63404918397"}</script></html>',
              200,
            );
          }
          if (request.method == 'POST' && request.url.path == '/api/graphql') {
            return http.Response(
              jsonEncode({
                'data': {
                  'mediaData': {
                    'threads': [
                      {
                        'thread_items': [
                          {
                            'post': {
                              'pk': '5',
                              'code': 'X',
                              'caption': {'text': 'via guest after cookie fail'},
                              'user': {'username': 'instagram', 'full_name': 'IG'},
                            },
                          },
                        ],
                      },
                    ],
                  },
                },
              }),
              200,
            );
          }
          return http.Response('unexpected ${request.url}', 500);
        }),
      );

      final posts = await client.fetchUserThreads('instagram');
      expect(posts.first.text, 'via guest after cookie fail');
    });

    test('guest GraphQL still works while a cookie session is cooling down', () async {
      await prefs.set(
        optionPluginThreadsDirectCooldownUntil,
        DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      );
      final client = ThreadsDirectClient(
        prefs,
        minGap: Duration.zero,
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              r'<html><script>["LSD",[],{"token":"tok"}]</script>'
              r'<script>{"username":"zuck","pk":"63055343223"}</script></html>',
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {
                'mediaData': {
                  'threads': [
                    {
                      'thread_items': [
                        {
                          'post': {
                            'pk': '3',
                            'code': 'z',
                            'caption': {'text': 'during cooldown'},
                            'user': {'username': 'zuck', 'full_name': 'Z'},
                          },
                        },
                      ],
                    },
                  ],
                },
              },
            }),
            200,
          );
        }),
      );

      final posts = await client.fetchGuestAccount('zuck');
      expect(posts.first.text, 'during cooldown');
    });

    test('fetchGuestAccount falls back to SSR when GraphQL returns empty', () async {
      final blob = jsonEncode({
        'thread_items': [
          {
            'post': {
              'pk': '7',
              'code': 'Ss',
              'caption': {'text': 'ssr fallback'},
              'user': {'username': 'zuck', 'full_name': 'Z'},
            },
          },
        ],
      });
      final client = ThreadsDirectClient(
        prefs,
        minGap: Duration.zero,
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              '<html><script type="application/json" data-sjs>$blob</script>'
              r'<script>["LSD",[],{"token":"t"}]</script>'
              r'<script>{"username":"zuck","pk":"63055343223"}</script></html>',
              200,
            );
          }
          return http.Response(jsonEncode({'data': {'mediaData': {'threads': []}}}), 200);
        }),
      );

      final posts = await client.fetchGuestAccount('zuck');
      expect(posts.first.text, 'ssr fallback');
    });
  });
}
