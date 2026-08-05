import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pref/pref.dart';
import 'package:xta/constants.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';

void main() {
  late PrefServiceCache prefs;

  setUp(() async {
    prefs = PrefServiceCache(cache: {
      optionPluginPixivRefreshToken: 'refresh-me',
      optionPluginPixivAccessToken: '',
      optionPluginPixivAccessExpiresAt: '',
      optionPluginPixivShowR18: false,
    });
  });

  group('PixivClient', () {
    test('refreshAccessToken stores tokens and returns the user', () async {
      final client = PixivClient(
        prefs,
        httpClient: MockClient((request) async {
          expect(request.url.host, 'oauth.secure.pixiv.net');
          expect(request.body, contains('grant_type=refresh_token'));
          expect(request.body, contains('refresh_token=refresh-me'));
          return http.Response(
            jsonEncode({
              'access_token': 'access-1',
              'refresh_token': 'refresh-2',
              'expires_in': 3600,
              'user': {'id': '123', 'name': 'Reader', 'account': 'reader'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final user = await client.refreshAccessToken();
      expect(user.name, 'Reader');
      expect(user.id, 123);
      expect(prefs.get<String>(optionPluginPixivAccessToken), 'access-1');
      expect(prefs.get<String>(optionPluginPixivRefreshToken), 'refresh-2');
    });

    test('following uses the access token and parses illusts', () async {
      await prefs.set(optionPluginPixivAccessToken, 'access-1');
      await prefs.set(optionPluginPixivAccessExpiresAt, DateTime.now().add(const Duration(hours: 1)).toIso8601String());

      final client = PixivClient(
        prefs,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v2/illust/follow');
          expect(request.headers['Authorization'], 'Bearer access-1');
          return http.Response(
            jsonEncode({
              'illusts': [
                {
                  'id': 1,
                  'title': 'Hi',
                  'caption': '',
                  'type': 'illust',
                  'image_urls': {'square_medium': 'https://i.pximg.net/a.jpg'},
                  'user': {'id': 2, 'name': 'A', 'account': 'a', 'profile_image_urls': {}},
                  'page_count': 1,
                  'x_restrict': 0,
                  'sanity_level': 2,
                }
              ],
              'next_url': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final page = await client.following();
      expect(page.illusts, hasLength(1));
      expect(page.illusts.first.title, 'Hi');
    });

    test('missing refresh token is notConfigured', () async {
      await prefs.set(optionPluginPixivRefreshToken, '');
      final client = PixivClient(prefs, httpClient: MockClient((_) async => http.Response('', 500)));
      await expectLater(
        client.verify(),
        throwsA(isA<PixivException>().having((e) => e.kind, 'kind', PixivErrorKind.notConfigured)),
      );
    });
  });
}
