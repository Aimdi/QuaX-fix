import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xta/plugins/substack/substack_models.dart';

/// Read-only Substack client using public per-publication JSON endpoints.
class SubstackClient {
  static final log = Logger('SubstackClient');

  final http.Client httpClient;

  SubstackClient({http.Client? httpClient}) : httpClient = httpClient ?? http.Client();

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  Future<SubstackPublication> fetchPublication(Uri base) async {
    final result = await _fetchPostMaps(base, limit: 1, offset: 0);
    if (result.posts.isEmpty) {
      return SubstackPublication(
        subdomain: subdomainOf(result.base),
        baseUrl: result.base.origin,
        name: subdomainOf(result.base),
      );
    }
    return publicationFromPostJson(result.posts.first, fallbackBase: result.base);
  }

  Future<List<SubstackPost>> fetchPosts(
    SubstackPublication publication, {
    int limit = 12,
    int offset = 0,
  }) async {
    final base = Uri.parse(publication.baseUrl);
    final result = await _fetchPostMaps(base, limit: limit, offset: offset);
    return result.posts
        .map((e) => SubstackPost.fromJson(
              e,
              publicationBaseUrl: publication.baseUrl,
              publicationName: publication.name,
              includeBody: false,
            ))
        .where((e) => e.title.isNotEmpty && e.slug.isNotEmpty)
        .toList();
  }

  Future<SubstackPost> fetchPost(SubstackPublication publication, String slug) async {
    final base = Uri.parse(publication.baseUrl);
    final uri = base.replace(path: '/api/v1/posts/$slug');
    final response = await _get(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw SubstackClientException('Unexpected response for $uri');
    }
    final post = SubstackPost.fromJson(
      Map<String, dynamic>.from(decoded),
      publicationBaseUrl: publication.baseUrl,
      publicationName: publication.name,
      includeBody: true,
    );
    if (post.title.isEmpty || post.slug.isEmpty) {
      throw SubstackClientException('Post not found: $slug');
    }
    return post;
  }

  Future<_PostsResult> _fetchPostMaps(Uri base, {required int limit, required int offset}) async {
    final uri = base.replace(path: '/api/v1/posts', queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
    });
    final response = await _get(uri);
    final effectiveBase = _effectiveBase(response, base);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return _PostsResult(base: effectiveBase, posts: const []);
    }
    final posts = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return _PostsResult(base: effectiveBase, posts: posts);
  }

  Future<http.Response> _get(Uri uri) async {
    final response = await httpClient.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': _ua,
    });
    if (response.statusCode != 200) {
      throw SubstackClientException('HTTP ${response.statusCode} loading $uri');
    }
    return response;
  }

  Uri _effectiveBase(http.Response response, Uri fallback) {
    final finalUrl = response.request?.url;
    if (finalUrl == null || finalUrl.host.isEmpty) return fallback;
    return Uri(scheme: 'https', host: finalUrl.host);
  }
}

class _PostsResult {
  final Uri base;
  final List<Map<String, dynamic>> posts;

  const _PostsResult({required this.base, required this.posts});
}

SubstackPublication publicationFromPostJson(Map<String, dynamic> post, {required Uri fallbackBase}) {
  final bylines = post['publishedBylines'];
  Map<String, dynamic>? publication;
  if (bylines is List && bylines.isNotEmpty) {
    final first = bylines.first;
    if (first is Map) {
      final users = first['publicationUsers'];
      if (users is List && users.isNotEmpty && users.first is Map) {
        final nested = users.first['publication'];
        if (nested is Map) publication = Map<String, dynamic>.from(nested);
      }
    }
  }

  final subdomain = publication?['subdomain'] as String? ?? subdomainOf(fallbackBase);
  final custom = publication?['custom_domain'] as String?;
  final baseUrl = custom != null && custom.isNotEmpty
      ? Uri(scheme: 'https', host: custom).origin
      : (publication != null ? 'https://$subdomain.substack.com' : fallbackBase.origin);

  return SubstackPublication(
    subdomain: subdomain,
    baseUrl: baseUrl,
    name: publication?['name'] as String? ?? subdomain,
    description: publication?['hero_text'] as String?,
    logoUrl: publication?['logo_url'] as String?,
  );
}

class SubstackClientException implements Exception {
  final String message;
  SubstackClientException(this.message);
  @override
  String toString() => message;
}
