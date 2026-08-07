import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xta/plugins/mastodon/mastodon_client.dart';
import 'package:xta/plugins/mastodon/mastodon_models.dart';

void main() {
  group('MastodonClient', () {
    test('verify prefers /api/v2/instance', () async {
      final client = MastodonClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v2/instance');
          expect(request.url.host, 'mastodon.social');
          return http.Response(jsonEncode({'domain': 'mastodon.social'}), 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      await client.verify('https://mastodon.social');
    });

    test('verify falls back to /api/v1/instance', () async {
      var calls = 0;
      final client = MastodonClient(
        httpClient: MockClient((request) async {
          calls++;
          if (request.url.path == '/api/v2/instance') {
            return http.Response('missing', 404);
          }
          expect(request.url.path, '/api/v1/instance');
          return http.Response(jsonEncode({'uri': 'https://old.example'}), 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      await client.verify('old.example');
      expect(calls, 2);
    });

    test('lookup parses a public account payload', () async {
      final client = MastodonClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/accounts/lookup');
          expect(request.url.queryParameters['acct'], 'gargron');
          return http.Response(
            jsonEncode({
              'id': '1',
              'username': 'Gargron',
              'acct': 'Gargron',
              'display_name': 'Eugen',
              'note': '',
              'url': 'https://mastodon.social/@Gargron',
              'followers_count': 1,
              'following_count': 2,
              'statuses_count': 3,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final profile = await client.lookup('https://mastodon.social', 'Gargron');
      expect(profile.id, '1');
      expect(profile.acct, 'gargron@mastodon.social');
      expect(profile.displayName, 'Eugen');
    });

    test('getStatuses returns parsed posts', () async {
      final client = MastodonClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/accounts/1/statuses');
          expect(request.url.queryParameters['limit'], '5');
          return http.Response(
            jsonEncode([
              {
                'id': '9',
                'created_at': '2026-08-01T09:00:00.000Z',
                'content': '<p>Hi</p>',
                'url': 'https://mastodon.social/@a/9',
                'account': {
                  'id': '1',
                  'username': 'a',
                  'acct': 'a',
                  'display_name': 'A',
                  'note': '',
                  'url': 'https://mastodon.social/@a',
                },
                'media_attachments': [],
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final posts = await client.getStatuses('https://mastodon.social', '1', limit: 5);
      expect(posts, hasLength(1));
      expect(posts.first.text, 'Hi');
    });

    test('fetchThread resolves a status URL then loads context', () async {
      final client = MastodonClient(
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/v2/search') {
            expect(request.url.queryParameters['q'], 'https://other.social/@b/22');
            expect(request.url.queryParameters['resolve'], 'true');
            return http.Response(
              jsonEncode({
                'statuses': [
                  {
                    'id': '100',
                    'created_at': '2026-08-01T09:00:00.000Z',
                    'content': '<p>Root</p>',
                    'url': 'https://other.social/@b/22',
                    'replies_count': 1,
                    'account': {
                      'id': '2',
                      'username': 'b',
                      'acct': 'b@other.social',
                      'display_name': 'B',
                      'note': '',
                      'url': 'https://other.social/@b',
                    },
                    'media_attachments': [],
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path == '/api/v1/statuses/100/context') {
            return http.Response(
              jsonEncode({
                'ancestors': [],
                'descendants': [
                  {
                    'id': '101',
                    'created_at': '2026-08-01T10:00:00.000Z',
                    'content': '<p>Reply</p>',
                    'url': 'https://other.social/@c/101',
                    'account': {
                      'id': '3',
                      'username': 'c',
                      'acct': 'c@other.social',
                      'display_name': 'C',
                      'note': '',
                      'url': 'https://other.social/@c',
                    },
                    'media_attachments': [],
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected ${request.url}', 500);
        }),
      );

      final seed = MastodonPost(
        id: '22',
        acct: 'b@other.social',
        authorName: 'B',
        text: 'Root',
        url: 'https://other.social/@b/22',
      );
      final thread = await client.fetchThread('https://mastodon.social', seed);
      expect(thread.status.id, '100');
      expect(thread.descendants, hasLength(1));
      expect(thread.descendants.first.text, 'Reply');
    });

    test('maps 404 and 429 to typed errors', () async {
      final notFound = MastodonClient(
        httpClient: MockClient((_) async => http.Response('missing', 404)),
      );
      await expectLater(
        notFound.lookup('https://mastodon.social', 'nobody'),
        throwsA(isA<MastodonException>().having((e) => e.kind, 'kind', MastodonErrorKind.notFound)),
      );

      final limited = MastodonClient(
        httpClient: MockClient((_) async => http.Response('slow', 429)),
      );
      await expectLater(
        limited.getStatuses('https://mastodon.social', '1'),
        throwsA(isA<MastodonException>().having((e) => e.kind, 'kind', MastodonErrorKind.rateLimited)),
      );
    });
  });
}
