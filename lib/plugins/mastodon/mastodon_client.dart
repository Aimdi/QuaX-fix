import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xta/plugins/mastodon/mastodon_models.dart';

/// Why a Mastodon read could not be served, in terms the screen explains it.
enum MastodonErrorKind { notConfigured, network, notFound, rateLimited, unauthorized, badResponse }

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

  /// Runs [read] against each instance in turn until one answers.
  ///
  /// A miss on one instance says nothing about the next: a 404 is also what a
  /// Misskey-family origin answers on the Mastodon API, and an instance that
  /// closed its public timeline still leaves every other candidate worth
  /// asking. When the whole walk fails, the error kept is the most telling
  /// one — a throttle or a refusal explains more than the 404 the least
  /// conclusive instance ended on.
  Future<T> firstInstanceThat<T>(List<String> instances, Future<T> Function(String instance) read) async {
    if (instances.isEmpty) {
      throw MastodonException(MastodonErrorKind.notConfigured, 'no instance to ask');
    }

    MastodonException? worst;
    for (final instance in instances) {
      try {
        return await read(instance);
      } on MastodonException catch (e) {
        worst = _moreTelling(worst, e);
      }
    }

    throw worst!;
  }

  static MastodonException? _moreTelling(MastodonException? a, MastodonException? b) {
    int rank(MastodonException? e) => switch (e?.kind) {
      MastodonErrorKind.rateLimited => 5,
      MastodonErrorKind.unauthorized => 4,
      MastodonErrorKind.badResponse => 3,
      MastodonErrorKind.network => 2,
      MastodonErrorKind.notFound => 1,
      MastodonErrorKind.notConfigured || null => 0,
    };

    return rank(b) > rank(a) ? b : a;
  }

  /// [lookup] over [instances]: the profile from the first instance that knows
  /// the account.
  Future<MastodonProfile> lookupAnywhere(List<String> instances, String acct) =>
      firstInstanceThat(instances, (instance) => lookup(instance, acct));

  /// [fetchAccount] over [instances].
  ///
  /// The lookup and the statuses read stay on whichever instance answered:
  /// account ids are instance-local, so an id resolved on one is meaningless
  /// on the next.
  Future<List<MastodonPost>> fetchAccountAnywhere(List<String> instances, String acct, {int limit = 20}) =>
      firstInstanceThat(instances, (instance) => fetchAccount(instance, acct, limit: limit));

  /// A profile and its first page of posts from one instance, walked the same
  /// way — both halves must come from the same place for the id to mean
  /// anything.
  Future<({MastodonProfile profile, List<MastodonPost> posts})> profileAnywhere(List<String> instances, String acct) =>
      firstInstanceThat(instances, (instance) async {
        final profile = await lookup(instance, acct);
        return (profile: profile, posts: await getStatuses(instance, profile.id));
      });

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
    final json = await _get(
      _uri(instance, '/api/v1/accounts/$id/statuses', {'limit': '$limit', 'exclude_replies': '$excludeReplies'}),
    );
    return parseMastodonStatuses(json, homeDomain: _homeDomain(instance));
  }

  /// Lookup then statuses — what the merged feed needs for one followed acct.
  Future<List<MastodonPost>> fetchAccount(String instance, String acct, {int limit = 20}) async {
    final profile = await lookup(instance, acct);
    return getStatuses(instance, profile.id, limit: limit);
  }
}
