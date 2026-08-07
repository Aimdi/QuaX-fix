import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xta/plugins/bluesky/bluesky_client.dart';

void main() {
  group('BlueskyClient', () {
    test('getProfile parses a public AppView payload', () async {
      final client = BlueskyClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/xrpc/app.bsky.actor.getProfile');
          expect(request.url.queryParameters['actor'], 'alice.bsky.social');
          expect(request.headers['User-Agent'], contains('XTA'));
          return http.Response(
            jsonEncode({
              'did': 'did:plc:abc',
              'handle': 'alice.bsky.social',
              'displayName': 'Alice',
              'description': 'Hi',
              'followersCount': 1,
              'followsCount': 2,
              'postsCount': 3,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final profile = await client.getProfile('alice.bsky.social');
      expect(profile.handle, 'alice.bsky.social');
      expect(profile.did, 'did:plc:abc');
      expect(profile.postsCount, 3);
    });

    test('getAuthorFeed returns posts and cursor', () async {
      final client = BlueskyClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/xrpc/app.bsky.feed.getAuthorFeed');
          expect(request.url.queryParameters['limit'], '5');
          return http.Response(
            jsonEncode({
              'cursor': 'next',
              'feed': [
                {
                  'post': {
                    'uri': 'at://did:plc:abc/app.bsky.feed.post/r1',
                    'cid': 'cid1',
                    'author': {
                      'did': 'did:plc:abc',
                      'handle': 'alice.bsky.social',
                      'displayName': 'Alice',
                    },
                    'record': {
                      'text': 'First',
                      'createdAt': '2026-08-01T10:00:00.000Z',
                    },
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final page = await client.getAuthorFeed('alice.bsky.social', limit: 5);
      expect(page.cursor, 'next');
      expect(page.posts, hasLength(1));
      expect(page.posts.first.text, 'First');
      expect(page.posts.first.url, 'https://bsky.app/profile/alice.bsky.social/post/r1');
    });

    test('maps 404 and 429 to typed errors', () async {
      final notFound = BlueskyClient(
        httpClient: MockClient((_) async => http.Response('missing', 404)),
      );
      await expectLater(
        notFound.getProfile('nobody.bsky.social'),
        throwsA(isA<BlueskyException>().having((e) => e.kind, 'kind', BlueskyErrorKind.notFound)),
      );

      final limited = BlueskyClient(
        httpClient: MockClient((_) async => http.Response('slow down', 429)),
      );
      await expectLater(
        limited.getAuthorFeed('alice.bsky.social'),
        throwsA(isA<BlueskyException>().having((e) => e.kind, 'kind', BlueskyErrorKind.rateLimited)),
      );
    });

    test('searchActors returns profiles from the actors list', () async {
      final client = BlueskyClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/xrpc/app.bsky.actor.searchActors');
          return http.Response(
            jsonEncode({
              'actors': [
                {'did': 'did:plc:1', 'handle': 'one.bsky.social', 'displayName': 'One'},
                {'did': 'did:plc:2', 'handle': 'two.bsky.social'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final actors = await client.searchActors('one', limit: 10);
      expect(actors, hasLength(2));
      expect(actors.first.handle, 'one.bsky.social');
      expect(actors.last.displayName, 'two.bsky.social');
    });

    test('getPostThread asks for the uri and flattens the tree', () async {
      final client = BlueskyClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/xrpc/app.bsky.feed.getPostThread');
          expect(request.url.queryParameters['uri'], 'at://did:plc:a/app.bsky.feed.post/focal');
          return http.Response(
            jsonEncode({
              'thread': {
                '\$type': 'app.bsky.feed.defs#threadViewPost',
                'post': {
                  'uri': 'at://did:plc:a/app.bsky.feed.post/focal',
                  'author': {'handle': 'alice.bsky.social'},
                  'record': {'text': 'focal', 'createdAt': '2026-08-01T10:00:00.000Z'},
                },
                'replies': [
                  {
                    '\$type': 'app.bsky.feed.defs#threadViewPost',
                    'post': {
                      'uri': 'at://did:plc:b/app.bsky.feed.post/r1',
                      'author': {'handle': 'bob.bsky.social'},
                      'record': {'text': 'reply', 'createdAt': '2026-08-01T11:00:00.000Z'},
                    },
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final thread = await client.getPostThread('at://did:plc:a/app.bsky.feed.post/focal');
      expect(thread.post.text, 'focal');
      expect(thread.replies.single.text, 'reply');
    });

    test('resolveBaseUrl is consulted per request and empty falls back', () async {
      var next = '';
      final client = BlueskyClient(
        resolveBaseUrl: () => next,
        httpClient: MockClient((request) async {
          expect(request.url.host, 'public.api.bsky.app');
          return http.Response(
            jsonEncode({'did': 'did:plc:z', 'handle': 'bsky.app'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.verify();
      next = 'https://custom.appview.test';
      final custom = BlueskyClient(
        resolveBaseUrl: () => next,
        httpClient: MockClient((request) async {
          expect(request.url.host, 'custom.appview.test');
          return http.Response(
            jsonEncode({'did': 'did:plc:z', 'handle': 'bsky.app'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await custom.verify();
    });
  });
}
