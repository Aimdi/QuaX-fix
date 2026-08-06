import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xta/plugins/mastodon/mastodon_models.dart';

/// Why a Mastodon read could not be served, in terms the screen explains it.
enum MastodonErrorKind {
  notConfigured,
  network,
  notFound,
  rateLimited,
  unauthorized,
  badResponse,
}

class MastodonException implements Exception {
  final MastodonErrorKind kind;
  final String message;

  MastodonException(this.kind, this.message);

  @override
  String toString() => 'MastodonException{$kind: $message}';
}

/// Reads public Mastodon / Fediverse data through a home instance — no login.
class MastodonClient {
  final http.Client httpClient;

  MastodonClient({http.Client? httpClient}) : httpClient = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 20);
  static const userAgent = 'XTA Mastodon plugin';

  Uri _uri(String instance, String path, [Map<String, String>? query]) {
    final base = normaliseMastodonInstance(instance);
    if (base == null) {
      throw MastodonException(MastodonErrorKind.notConfigured, 'bad instance: $instance');
    }
    final root = Uri.parse(base);
    return Uri(
      scheme: root.scheme,
      host: root.host,
      port: root.hasPort ? root.port : null,
      path: path,
      queryParameters: query,
    );
  }

  Future<Object?> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await httpClient
          .get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'})
          .timeout(_timeout);
    } catch (e) {
      throw MastodonException(MastodonErrorKind.network, '$uri: $e');
    }

    if (response.statusCode == 404) {
      throw MastodonException(MastodonErrorKind.notFound, '$uri: 404');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw MastodonException(MastodonErrorKind.unauthorized, '$uri: ${response.statusCode}');
    }
    if (response.statusCode == 429) {
      throw MastodonException(MastodonErrorKind.rateLimited, '$uri: 429');
    }
    if (response.statusCode != 200) {
      throw MastodonException(MastodonErrorKind.badResponse, '$uri: ${response.statusCode}');
    }

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      throw MastodonException(MastodonErrorKind.badResponse, '$uri: $e');
    }
  }

  /// Confirms the instance answers the public instance metadata endpoint.
  Future<void> verify(String instance) async {
    try {
      await _get(_uri(instance, '/api/v2/instance'));
    } on MastodonException catch (e) {
      if (e.kind == MastodonErrorKind.notFound) {
        await _get(_uri(instance, '/api/v1/instance'));
        return;
      }
      rethrow;
    }
  }

  String? _homeDomain(String instance) => mastodonInstanceDomain(normaliseMastodonInstance(instance) ?? instance);

  /// Resolve [acct] (local username or `user@domain`) on the home instance.
  Future<MastodonProfile> lookup(String instance, String acct) async {
    final normalised = normaliseMastodonAcct(acct);
    if (normalised == null) {
      throw MastodonException(MastodonErrorKind.notFound, 'invalid acct: $acct');
    }

    final json = await _get(_uri(instance, '/api/v1/accounts/lookup', {'acct': normalised}));
    final profile = MastodonProfile.fromJson(json, homeDomain: _homeDomain(instance));
    if (profile.id.isEmpty || profile.acct.isEmpty) {
      throw MastodonException(MastodonErrorKind.badResponse, 'empty profile for $normalised');
    }
    return profile;
  }

  Future<MastodonProfile> getAccount(String instance, String id) async {
    final json = await _get(_uri(instance, '/api/v1/accounts/$id'));
    return MastodonProfile.fromJson(json, homeDomain: _homeDomain(instance));
  }

  /// Recent public statuses by local account [id], newest first.
  Future<List<MastodonPost>> getStatuses(
    String instance,
    String id, {
    int limit = 20,
    bool excludeReplies = true,
  }) async {
    final json = await _get(_uri(instance, '/api/v1/accounts/$id/statuses', {
      'limit': '$limit',
      'exclude_replies': '$excludeReplies',
    }));
    return parseMastodonStatuses(json, homeDomain: _homeDomain(instance));
  }

  /// Lookup then statuses — what the merged feed needs for one followed acct.
  Future<List<MastodonPost>> fetchAccount(String instance, String acct, {int limit = 20}) async {
    final profile = await lookup(instance, acct);
    return getStatuses(instance, profile.id, limit: limit);
  }
}
