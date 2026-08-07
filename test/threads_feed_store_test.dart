import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pref/pref.dart';
import 'package:xta/constants.dart';
import 'package:xta/plugins/threads/threads_client.dart';
import 'package:xta/plugins/threads/threads_direct_client.dart';
import 'package:xta/plugins/threads/threads_models.dart';
import 'package:xta/plugins/threads/threads_store.dart';

class _AccountsStub extends ThreadsAccountsStore {
  _AccountsStub(List<ThreadsAccount> accounts) {
    update(accounts);
  }

  @override
  Future<void> load() async {}
}

void main() {
  test('refresh loads Accounts even when a Bearer is pasted', () async {
    final prefs = PrefServiceCache(cache: {
      optionPluginThreadsDirectCookies: '',
      optionPluginThreadsDirectBearer: 'IGT:2:secret',
      optionPluginThreadsDirectDeviceId: 'device-1',
      optionPluginThreadsInstance: '',
      optionPluginThreadsUserIds: '{}',
      optionPluginThreadsDirectCooldownUntil: '',
    });

    var followingCalled = false;
    final direct = ThreadsDirectClient(
      prefs,
      minGap: Duration.zero,
      httpClient: MockClient((request) async {
        if (request.url.host == 'i.instagram.com') {
          followingCalled = true;
          return http.Response('{"threads":[]}', 200);
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
            '''{"data":{"mediaData":{"threads":[{"thread_items":[{"post":{"pk":"1","code":"c","caption":{"text":"account post"},"user":{"username":"instagram","full_name":"IG"}}}]}]}}}''',
            200,
          );
        }
        return http.Response('unexpected ${request.url}', 500);
      }),
    );

    final store = ThreadsFeedStore(
      ThreadsClient(httpClient: MockClient((_) async => http.Response('[]', 404))),
      direct,
      prefs,
      _AccountsStub([const ThreadsAccount(handle: 'instagram', name: 'instagram')]),
    );

    await store.refresh(force: true);
    expect(store.state.map((p) => p.text), ['account post']);
    expect(followingCalled, isFalse);
  });
}
