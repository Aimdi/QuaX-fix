/// Registry of the X GraphQL endpoints the app calls.
///
/// X rotates the query id in `/i/api/graphql/<queryId>/<Operation>` without
/// notice. When it does, that operation starts returning 404 and the feature
/// silently dies until a new APK ships. Keeping every id here instead of inline
/// at the call site means a rotation can be repaired by [applyOverrides] — see
/// `endpoint_overrides.dart` — rather than by a release.
library;

class XEndpoint {
  /// Registry key. Usually the operation name; suffixed when two call sites use
  /// the same operation with different ids (see `SearchTimelineUsers`).
  final String name;

  /// GraphQL operation as it appears in the path.
  final String operation;

  /// Query id shipped with this build, used until an override replaces it.
  final String queryId;

  /// X serves the same graph from both hostnames but the ids are not
  /// interchangeable, so each endpoint pins the host it was captured from.
  final String host;

  const XEndpoint({
    required this.name,
    required this.operation,
    required this.queryId,
    required this.host,
  });

  String pathFor(String id) => '/i/api/graphql/$id/$operation';
}

/// A query id is 22 URL-safe base64 characters. Overrides are matched against
/// this so a malformed or hostile registry file can never inject path segments:
/// the request still goes to a known operation on a pinned host.
final RegExp queryIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,32}$');

class XEndpoints {
  static const userByRestId = 'UserByRestId';
  static const userByScreenName = 'UserByScreenName';
  static const following = 'Following';
  static const followers = 'Followers';
  static const listByRestId = 'ListByRestId';
  static const listMembers = 'ListMembers';
  static const tweetDetail = 'TweetDetail';
  static const searchTimeline = 'SearchTimeline';
  static const searchTimelineUsers = 'SearchTimelineUsers';
  static const homeTimeline = 'HomeTimeline';
  static const userMedia = 'UserMedia';
  static const userTweetsAndReplies = 'UserTweetsAndReplies';
  static const userTweets = 'UserTweets';

  static const Map<String, XEndpoint> shipped = {
    userByRestId: XEndpoint(
      name: userByRestId,
      operation: 'UserByRestId',
      queryId: 'Qs44y3K0SXxItjNi6mUFQA',
      host: 'twitter.com',
    ),
    userByScreenName: XEndpoint(
      name: userByScreenName,
      operation: 'UserByScreenName',
      queryId: 'qW5u-DAuXpMEG0zA1F7UGQ',
      host: 'twitter.com',
    ),
    following: XEndpoint(
      name: following,
      operation: 'Following',
      queryId: 'FEcMGoVOUjm0aU9BJrrGZA',
      host: 'x.com',
    ),
    followers: XEndpoint(
      name: followers,
      operation: 'Followers',
      queryId: '4yeuNabfz3qFlfncCAy8Yw',
      host: 'x.com',
    ),
    listByRestId: XEndpoint(
      name: listByRestId,
      operation: 'ListByRestId',
      queryId: 'I1h1FzuuiD__nNvG466mKQ',
      host: 'x.com',
    ),
    listMembers: XEndpoint(
      name: listMembers,
      operation: 'ListMembers',
      queryId: 'kcsJubZ1BIwpdKrYfiNRtg',
      host: 'x.com',
    ),
    tweetDetail: XEndpoint(
      name: tweetDetail,
      operation: 'TweetDetail',
      queryId: 'xIYgDwjboktoFeXe_fgacw',
      host: 'x.com',
    ),
    searchTimeline: XEndpoint(
      name: searchTimeline,
      operation: 'SearchTimeline',
      queryId: '-TFXKoMnMTKdEXcCn-eahw',
      host: 'x.com',
    ),
    // People search hits the same operation with a different id and host.
    searchTimelineUsers: XEndpoint(
      name: searchTimelineUsers,
      operation: 'SearchTimeline',
      queryId: '-KWrbTBsPifMuLUqqDiU_A',
      host: 'twitter.com',
    ),
    homeTimeline: XEndpoint(
      name: homeTimeline,
      operation: 'HomeTimeline',
      queryId: 'W4Tpu1uueTGK53paUgxF0Q',
      host: 'twitter.com',
    ),
    userMedia: XEndpoint(
      name: userMedia,
      operation: 'UserMedia',
      queryId: '36oKqyQ7E_9CmtONGjJRsA',
      host: 'x.com',
    ),
    userTweetsAndReplies: XEndpoint(
      name: userTweetsAndReplies,
      operation: 'UserTweetsAndReplies',
      queryId: 'T52C7z3XOxUTSsIn1sQ5MA',
      host: 'x.com',
    ),
    userTweets: XEndpoint(
      name: userTweets,
      operation: 'UserTweets',
      queryId: '2GIWTr7XwadIixZDtyXd4A',
      host: 'x.com',
    ),
  };

  static Map<String, String> _overrides = const {};

  /// Query ids currently replacing a shipped one. Empty on a fresh install.
  static Map<String, String> get overrides => Map.unmodifiable(_overrides);

  /// Replaces shipped query ids. Entries naming an unknown endpoint or carrying
  /// a value that is not query-id shaped are ignored; the return value is how
  /// many were accepted, so a caller can log a partially rejected payload.
  static int applyOverrides(Map<String, String> ids) {
    final accepted = <String, String>{};
    ids.forEach((name, id) {
      if (shipped.containsKey(name) && queryIdPattern.hasMatch(id)) {
        accepted[name] = id;
      }
    });
    _overrides = accepted;
    return accepted.length;
  }

  static void clearOverrides() => _overrides = const {};

  static XEndpoint endpoint(String name) {
    final endpoint = shipped[name];
    if (endpoint == null) {
      throw ArgumentError('Unknown X endpoint "$name"');
    }
    return endpoint;
  }

  /// The query id in force for [name] — the override if one applies, else the
  /// id this build shipped with.
  static String queryId(String name) => _overrides[name] ?? endpoint(name).queryId;

  static bool isOverridden(String name) => _overrides.containsKey(name);

  static String path(String name) => endpoint(name).pathFor(queryId(name));

  static Uri uri(String name, Map<String, dynamic> params) =>
      Uri.https(endpoint(name).host, path(name), params);

  static List<XEndpoint> get all => shipped.values.toList(growable: false);
}
