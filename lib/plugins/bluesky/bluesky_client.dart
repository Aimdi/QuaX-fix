import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xta/plugins/bluesky/bluesky_models.dart';
import 'package:xta/utils/json.dart';

/// Why a Bluesky read could not be served, in terms the screen explains it.
enum BlueskyErrorKind {
  network,
  notFound,
  rateLimited,
  badResponse,
}

class BlueskyException implements Exception {
  final BlueskyErrorKind kind;
  final String message;

  BlueskyException(this.kind, this.message);

  @override
  String toString() => 'BlueskyException{$kind: $message}';
}

/// One page of an author feed from the public AppView.
class BlueskyFeedPage {
  final List<BlueskyPost> posts;
  final String? cursor;

  const BlueskyFeedPage({required this.posts, this.cursor});
}

/// Reads Bluesky through the public AppView — no account, no write actions.
class BlueskyClient {
  final http.Client httpClient;
  final String baseUrl;

  BlueskyClient({http.Client? httpClient, this.baseUrl = 'https://public.api.bsky.app'})
      : httpClient = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 20);
  static const userAgent = 'XTA Bluesky plugin';

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<Json> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await httpClient
          .get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'})
          .timeout(_timeout);
    } catch (e) {
      throw BlueskyException(BlueskyErrorKind.network, '$uri: $e');
    }

    if (response.statusCode == 404) {
      throw BlueskyException(BlueskyErrorKind.notFound, '$uri: 404');
    }
    if (response.statusCode == 429) {
      throw BlueskyException(BlueskyErrorKind.rateLimited, '$uri: 429');
    }
    if (response.statusCode != 200) {
      throw BlueskyException(BlueskyErrorKind.badResponse, '$uri: ${response.statusCode}');
    }

    try {
      return Json(jsonDecode(utf8.decode(response.bodyBytes)));
    } catch (e) {
      throw BlueskyException(BlueskyErrorKind.badResponse, '$uri: $e');
    }
  }

  /// Profile for [actor] (handle or DID).
  Future<BlueskyProfile> getProfile(String actor) async {
    final json = await _get(_uri('/xrpc/app.bsky.actor.getProfile', {'actor': actor}));
    final profile = BlueskyProfile.fromJson(json.raw);
    if (profile.did.isEmpty && profile.handle.isEmpty) {
      throw BlueskyException(BlueskyErrorKind.badResponse, 'empty profile for $actor');
    }
    return profile;
  }

  /// Recent posts by [actor], newest first within the page.
  Future<BlueskyFeedPage> getAuthorFeed(String actor, {int limit = 20, String? cursor}) async {
    final query = <String, String>{
      'actor': actor,
      'limit': '$limit',
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }

    final json = await _get(_uri('/xrpc/app.bsky.feed.getAuthorFeed', query));
    return BlueskyFeedPage(
      posts: parseBlueskyFeed(json.raw),
      cursor: json['cursor'].string,
    );
  }

  /// Actors matching [q], as the AppView's search returns them.
  Future<List<BlueskyProfile>> searchActors(String q, {int limit = 10}) async {
    final json = await _get(_uri('/xrpc/app.bsky.actor.searchActors', {
      'q': q,
      'limit': '$limit',
    }));
    return [
      for (final actor in json['actors'].list) BlueskyProfile.fromJson(actor.raw),
    ];
  }
}
