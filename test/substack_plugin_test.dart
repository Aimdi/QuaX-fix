import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quax/plugins/substack/substack_client.dart';
import 'package:quax/plugins/substack/substack_models.dart';

void main() {
  test('resolveSubstackBase accepts handle and URL', () {
    expect(resolveSubstackBase('astralcodexten')?.host, 'astralcodexten.substack.com');
    expect(resolveSubstackBase('https://astralcodexten.substack.com/p/x')?.origin, 'https://astralcodexten.substack.com');
    expect(resolveSubstackBase('www.astralcodexten.com')?.host, 'www.astralcodexten.com');
    expect(resolveSubstackBase(''), isNull);
  });

  test('publicationFromPostJson reads nested publication metadata', () {
    final pub = publicationFromPostJson({
      'publishedBylines': [
        {
          'publicationUsers': [
            {
              'publication': {
                'name': 'Astral Codex Ten',
                'subdomain': 'astralcodexten',
                'custom_domain': 'www.astralcodexten.com',
                'hero_text': 'commentary',
                'logo_url': 'https://example.com/logo.png',
              }
            }
          ]
        }
      ]
    }, fallbackBase: Uri.parse('https://astralcodexten.substack.com'));

    expect(pub.name, 'Astral Codex Ten');
    expect(pub.subdomain, 'astralcodexten');
    expect(pub.baseUrl, 'https://www.astralcodexten.com');
    expect(pub.description, 'commentary');
  });

  test('SubstackClient.fetchPosts parses public JSON without body', () async {
    final client = SubstackClient(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/posts');
        return http.Response(
          '''
          [{
            "id": 1,
            "title": "Hello",
            "slug": "hello",
            "subtitle": "world",
            "post_date": "2026-07-01T00:00:00.000Z",
            "canonical_url": "https://example.substack.com/p/hello",
            "audience": "everyone",
            "body_html": "<p>secret</p>",
            "publishedBylines": [{"name": "Author"}]
          }]
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final posts = await client.fetchPosts(
      const SubstackPublication(
        subdomain: 'example',
        baseUrl: 'https://example.substack.com',
        name: 'Example',
      ),
    );

    expect(posts, hasLength(1));
    expect(posts.first.title, 'Hello');
    expect(posts.first.authorName, 'Author');
    expect(posts.first.isPaywalled, isFalse);
    expect(posts.first.bodyHtml, isNull);
  });

  test('SubstackClient.fetchPost loads full body', () async {
    final client = SubstackClient(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/posts/hello');
        return http.Response(
          '''
          {
            "id": 1,
            "title": "Hello",
            "slug": "hello",
            "audience": "only_paying",
            "body_html": "<p>full</p>",
            "canonical_url": "https://example.substack.com/p/hello"
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final post = await client.fetchPost(
      const SubstackPublication(
        subdomain: 'example',
        baseUrl: 'https://example.substack.com',
        name: 'Example',
      ),
      'hello',
    );

    expect(post.bodyHtml, '<p>full</p>');
    expect(post.isPaywalled, isTrue);
  });

  test('SubstackPublication prefs round-trip', () {
    const pubs = [
      SubstackPublication(subdomain: 'a', baseUrl: 'https://a.substack.com', name: 'A'),
    ];
    final raw = SubstackPublication.listToPrefs(pubs);
    final back = SubstackPublication.listFromPrefs(raw);
    expect(back.single.name, 'A');
    expect(back.single.id, 'a');
  });
}
