import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:pref/pref.dart';
import 'package:xta/constants.dart';
import 'package:xta/plugins/threads/threads_client.dart';
import 'package:xta/plugins/threads/threads_models.dart';
import 'package:xta/utils/json.dart';

const _threadsWeb = 'https://www.threads.com';
const _instagramApi = 'https://i.instagram.com';
const _igAppId = '238260118697367';
const _barcelonaUa = 'Barcelona 289.0.0.77.109 Android';
const _safariUa =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';

/// Guest profile threads — `BarcelonaProfileThreadsTabQuery`. Rotates; if it
/// 404s or returns empty, [fetchGuestAccount] falls back to SSR `thread_items`.
const threadsGuestProfileThreadsDocId = '6232751443445612';

final _lsdTokenPattern = RegExp(r'"LSD",\[\],\{"token":"([^"]+)"\}');

/// Cookie names a browser Threads session must carry for cookie REST reads.
const _requiredCookieKeys = ['sessionid', 'csrftoken', 'ds_user_id', 'mid', 'ig_did'];

/// Parses a pasted Cookie header (or `name=value; …`) into a map.
Map<String, String> parseThreadsCookieHeader(String raw) {
  final out = <String, String>{};
  for (final part in raw.split(';')) {
    final i = part.indexOf('=');
    if (i <= 0) continue;
    final name = part.substring(0, i).trim();
    final value = part.substring(i + 1).trim();
    if (name.isNotEmpty && value.isNotEmpty) {
      out[name] = value;
    }
  }
  return out;
}

/// True when the paste includes every cookie the cookie REST path needs.
bool threadsCookiesComplete(Map<String, String> cookies) =>
    _requiredCookieKeys.every((k) => (cookies[k] ?? '').isNotEmpty);

String? normaliseThreadsBearer(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;
  if (value.toLowerCase().startsWith('bearer ')) {
    value = value.substring(7).trim();
  }
  if (!value.startsWith('IGT:2:')) return null;
  return value;
}

/// Pure parsers for Meta JSON / SSR — kept free of I/O for unit tests.
List<ThreadsPost> parseThreadsApiFeed(Object? json) {
  final root = Json(json);
  final buckets = root['threads'].list.isNotEmpty ? root['threads'].list : root['items'].list;
  final posts = <ThreadsPost>[];
  for (final bucket in buckets) {
    final items = bucket['thread_items'].list;
    final postJson = items.isNotEmpty ? items.first['post'] : bucket['post'];
    final post = threadsPostFromApi(postJson);
    if (post != null) posts.add(post);
  }
  return posts;
}

/// Guest GraphQL profile tab: `data.mediaData.threads` → same post shape as REST.
List<ThreadsPost> parseThreadsGraphqlFeed(Object? json) {
  final root = Json(json);
  final mediaThreads = root['data']['mediaData']['threads'].list;
  if (mediaThreads.isEmpty) {
    return parseThreadsApiFeed(json);
  }
  return parseThreadsApiFeed({
    'threads': [for (final thread in mediaThreads) thread.raw],
  });
}

/// LSD token embedded in Threads HTML for guest GraphQL.
String? extractThreadsLsd(String html) => _lsdTokenPattern.firstMatch(html)?.group(1);

/// Numeric Threads user id for [handle] from a profile page HTML blob.
String? extractThreadsUserIdFromHtml(String html, String handle) {
  final key = handle.trim().toLowerCase();
  if (key.isEmpty) return null;
  final escaped = RegExp.escape(key);
  final nearUsername = RegExp(
    '"username"\\s*:\\s*"$escaped".{0,480}?"pk"\\s*:\\s*"(\\d+)"',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  if (nearUsername != null) return nearUsername.group(1);

  final nearPk = RegExp(
    '"pk"\\s*:\\s*"(\\d+)".{0,480}?"username"\\s*:\\s*"$escaped"',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  if (nearPk != null) return nearPk.group(1);

  final userIds = RegExp(r'"userID"\s*:\s*"(\d+)"').allMatches(html).map((m) => m.group(1)!).toList();
  if (userIds.isEmpty) return null;
  // Profile pages usually repeat the owner's id; prefer the mode.
  final counts = <String, int>{};
  for (final id in userIds) {
    counts[id] = (counts[id] ?? 0) + 1;
  }
  final ranked = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return ranked.first.key;
}

ThreadsPost? threadsPostFromApi(Json post) {
  if (!post.exists) return null;
  final user = post['user'];
  final handle = (user['username'].string ?? '').trim().toLowerCase();
  final text = (post['caption']['text'].string ?? '').trim();
  final images = _imageUrlsOf(post);
  if (handle.isEmpty || (text.isEmpty && images.isEmpty)) return null;

  final code = post['code'].string;
  final pk = post['pk'].string ?? post['id'].string ?? code;
  if (pk == null || pk.isEmpty) return null;

  final taken = post['taken_at'].integer;
  return ThreadsPost(
    id: pk,
    handle: handle,
    authorName: (user['full_name'].string ?? '').trim().isEmpty ? handle : user['full_name'].string!.trim(),
    avatarUrl: user['profile_pic_url'].string ?? user['hd_profile_pic_url_info']['url'].string,
    text: text,
    images: images,
    publishedAt: taken == null ? null : DateTime.fromMillisecondsSinceEpoch(taken * 1000, isUtc: true).toLocal(),
    url: code == null ? null : '$_threadsWeb/@$handle/post/$code',
  );
}

List<String> _imageUrlsOf(Json post) {
  final urls = <String>[];
  void add(String? url) {
    if (url != null && url.isNotEmpty && !urls.contains(url)) urls.add(url);
  }

  add(post['image_versions2']['candidates'][0]['url'].string);
  for (final media in post['carousel_media'].list) {
    add(media['image_versions2']['candidates'][0]['url'].string);
  }
  return urls;
}

ThreadsProfile? threadsProfileFromUserJson(Json user) {
  if (!user.exists) return null;
  final username = (user['username'].string ?? '').trim();
  if (username.isEmpty) return null;
  final pk = user['pk'].string ?? user['id'].string ?? user['pk_id'].string ?? '';
  final url = user['external_url'].string?.trim();
  return ThreadsProfile(
    pk: pk,
    id: user['id'].string ?? pk,
    username: username,
    fullName: user['full_name'].string ?? '',
    isVerified: user['is_verified'].boolean ?? false,
    isPrivate: user['is_private'].boolean ?? false,
    profilePicUrl: user['profile_pic_url'].string ?? user['hd_profile_pic_url_info']['url'].string ?? '',
    biography: user['biography'].string ?? '',
    followerCount: user['follower_count'].integer ?? 0,
    followingCount: user['following_count'].integer ?? 0,
    mediaCount: user['media_count'].integer ?? 0,
    externalUrl: url == null || url.isEmpty ? null : url,
  );
}

/// Walks decoded `data-sjs` blobs for `thread_items` posts.
List<ThreadsPost> parseThreadsSsrHtml(String body, String handle) {
  final document = html_parser.parse(body);
  final posts = <ThreadsPost>[];
  final seen = <String>{};

  for (final script in document.querySelectorAll('script[data-sjs]')) {
    final text = script.text.trim();
    if (text.isEmpty || !text.contains('thread_items')) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      continue;
    }
    _collectSsrPosts(decoded, handle, posts, seen);
  }
  return posts;
}

void _collectSsrPosts(Object? node, String handle, List<ThreadsPost> out, Set<String> seen) {
  if (node is Map) {
    final items = node['thread_items'];
    if (items is List && items.isNotEmpty) {
      final post = threadsPostFromApi(Json(items.first is Map ? (items.first as Map)['post'] : null));
      if (post != null && (post.handle == handle || handle.isEmpty) && seen.add(post.id)) {
        out.add(post);
      }
    }
    for (final value in node.values) {
      _collectSsrPosts(value, handle, out, seen);
    }
  } else if (node is List) {
    for (final value in node) {
      _collectSsrPosts(value, handle, out, seen);
    }
  }
}

/// Read-only Meta client: cookies on threads.com, Bearer on i.instagram.com,
/// guest SSR when neither is set.
class ThreadsDirectClient {
  final http.Client httpClient;
  final BasePrefService prefs;
  final Duration minGap;
  DateTime? _lastRequestAt;
  DateTime? _cooldownUntil;

  ThreadsDirectClient(this.prefs, {http.Client? httpClient, this.minGap = const Duration(seconds: 2)})
    : httpClient = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 25);

  Map<String, String> get cookies =>
      parseThreadsCookieHeader(prefs.get<String>(optionPluginThreadsDirectCookies) ?? '');

  String? get bearer => normaliseThreadsBearer(prefs.get<String>(optionPluginThreadsDirectBearer) ?? '');

  bool get hasCookies => threadsCookiesComplete(cookies);

  bool get hasBearer => bearer != null;

  bool get hasDirectAuth => hasCookies || hasBearer;

  Future<String> _deviceId() async {
    final existing = (prefs.get<String>(optionPluginThreadsDirectDeviceId) ?? '').trim();
    if (existing.isNotEmpty) return existing;
    final created = _randomDeviceId();
    await prefs.set(optionPluginThreadsDirectDeviceId, created);
    return created;
  }

  /// Requests leave one at a time, in order.
  ///
  /// [_pace] used to be awaited concurrently: two fetches both read
  /// [_lastRequestAt], both computed the same wait, and both fired at the end
  /// of it — so the gap between requests was never actually kept and Meta saw
  /// bursts. A queue is what makes the gap real, and looking like one person
  /// reading is the whole defence this plugin has.
  Future<void> _queue = Future<void>.value();

  final Random _jitter = Random();

  /// Serialises [run] behind every request already waiting, and keeps the gap.
  Future<T> _enqueue<T>(Future<T> Function() run) {
    final result = _queue.then((_) async {
      await _pace();
      return run();
    });
    // A failure must not poison the queue for everything behind it.
    _queue = result.then((_) {}, onError: (Object _) {});

    return result;
  }

  Future<void> _pace() async {
    if (await _coolingDown() case final until?) {
      throw ThreadsException(ThreadsErrorKind.sessionSuspended, 'cooling down until $until');
    }

    final last = _lastRequestAt;
    if (last != null) {
      // A gap that is exactly the same every time is its own signature, so the
      // wait is the floor plus a little noise.
      final gap = minGap + Duration(milliseconds: _jitter.nextInt(750));
      final wait = gap - DateTime.now().difference(last);
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
    }
    _lastRequestAt = DateTime.now();
  }

  /// When the session is parked, or null when it may talk to Meta.
  Future<DateTime?> _coolingDown() async {
    final stored = DateTime.tryParse(prefs.get<String>(optionPluginThreadsDirectCooldownUntil) ?? '');
    final until = stored ?? _cooldownUntil;
    if (until == null) {
      return null;
    }
    if (DateTime.now().isBefore(until)) {
      return until;
    }

    _cooldownUntil = null;
    if (stored != null) {
      await prefs.set(optionPluginThreadsDirectCooldownUntil, '');
    }

    return null;
  }

  /// Backs off after Meta says to.
  ///
  /// Written to preferences as well as held here: a cooldown that only lives in
  /// memory ends the moment the reader force-quits, and coming straight back
  /// for more is exactly what turns a throttle into a ban.
  void _armCooldown([Duration length = const Duration(minutes: 30)]) {
    final until = DateTime.now().add(length);
    _cooldownUntil = until;
    // `set` is a FutureOr, and this is called from a synchronous throw path.
    unawaited(Future<void>.sync(() => prefs.set(optionPluginThreadsDirectCooldownUntil, until.toIso8601String())));
  }

  Future<http.Response> _get(Uri uri, Map<String, String> headers) {
    return _enqueue(() async {
      try {
        return await httpClient.get(uri, headers: headers).timeout(_timeout);
      } catch (e) {
        throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: $e');
      }
    });
  }

  Future<http.Response> _post(Uri uri, Map<String, String> headers, String body) {
    return _enqueue(() async {
      try {
        return await httpClient.post(uri, headers: headers, body: body).timeout(_timeout);
      } catch (e) {
        throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: $e');
      }
    });
  }

  void _throwForStatus(http.Response response, Uri uri) {
    final body = utf8.decode(response.bodyBytes);
    final loginRequired = body.contains('login_required') || body.contains('logout_reason');
    if (response.statusCode == 429 || body.contains('Please wait a few minutes')) {
      _armCooldown();
      throw ThreadsException(ThreadsErrorKind.throttled, '$uri: rate limited');
    }
    if (response.statusCode == 401 || response.statusCode == 403 || loginRequired) {
      if (loginRequired) _armCooldown();
      throw ThreadsException(
        loginRequired ? ThreadsErrorKind.sessionSuspended : ThreadsErrorKind.unauthorized,
        '$uri: ${response.statusCode}',
      );
    }
    if (response.statusCode == 404) {
      throw ThreadsException(ThreadsErrorKind.noSuchFeed, '$uri: 404');
    }
    if (response.statusCode != 200) {
      throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: ${response.statusCode}');
    }
  }

  Object? _decodeJson(http.Response response, Uri uri) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: $e');
    }
  }

  Map<String, String> _cookieHeaders() {
    final c = cookies;
    final cookieHeader = _requiredCookieKeys.map((k) => '$k=${c[k]}').join('; ');
    return {
      'User-Agent': _barcelonaUa,
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
      'X-IG-App-ID': _igAppId,
      'X-CSRFToken': c['csrftoken']!,
      'X-ASBD-ID': '129477',
      'X-IG-WWW-Claim': '0',
      'Referer': '$_threadsWeb/',
      'Cookie': cookieHeader,
    };
  }

  Future<Map<String, String>> _bearerHeaders() async => {
    'User-Agent': _barcelonaUa,
    'Authorization': 'Bearer ${bearer!}',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'X-IG-App-ID': _igAppId,
    'X-IG-Capabilities': '3brTvx0=',
    'X-IG-Connection-Type': 'WIFI',
    'X-IG-Device-ID': await _deviceId(),
  };

  /// Confirms cookies via current_user and/or Bearer via a tiny timeline fetch.
  Future<String> verify() async {
    if (!hasDirectAuth) {
      throw ThreadsException(ThreadsErrorKind.notConfigured, 'no direct session');
    }
    if (hasCookies) {
      final me = await currentUser();
      return me.username;
    }
    final posts = await fetchFollowingTimeline(limit: 1);
    return posts.isEmpty ? 'ok' : posts.first.handle;
  }

  Future<ThreadsProfile> currentUser() async {
    _requireCookies();
    final uri = Uri.parse('$_threadsWeb/api/v1/accounts/current_user/').replace(queryParameters: {'edit': 'true'});
    final response = await _get(uri, _cookieHeaders());
    _throwForStatus(response, uri);
    final user = Json(_decodeJson(response, uri))['user'];
    final profile = threadsProfileFromUserJson(user);
    if (profile == null) {
      throw ThreadsException(ThreadsErrorKind.unreachable, 'current_user missing user');
    }
    return profile;
  }

  /// The numeric id behind [handle], remembered once it is known.
  ///
  /// Resolving it costs a call to Meta's *search* endpoint, so asking the same
  /// question about the same followed accounts on every refresh both doubles
  /// what a read costs and looks precisely like a script. An account's id does
  /// not change, so it is worth keeping.
  Future<String> resolveUserId(String handle) async {
    final key = handle.toLowerCase();
    final known = _storedUserIds();
    if (known[key] case final id? when id.isNotEmpty) {
      return id;
    }

    _requireCookies();
    final id = await _searchUserId(key);
    await _rememberUserId(key, id);
    return id;
  }

  Map<String, String> _storedUserIds() {
    try {
      final decoded = jsonDecode(prefs.get<String>(optionPluginThreadsUserIds) ?? '{}');
      return decoded is Map ? {for (final e in decoded.entries) '${e.key}': '${e.value}'} : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _rememberUserId(String handle, String id) async {
    final key = handle.toLowerCase();
    if (key.isEmpty || id.isEmpty) return;
    final known = _storedUserIds();
    if (known[key] == id) return;
    await prefs.set(optionPluginThreadsUserIds, jsonEncode({...known, key: id}));
  }

  Future<String> _searchUserId(String handle) async {
    final uri = Uri.parse('$_threadsWeb/api/v1/users/search/').replace(queryParameters: {'q': handle, 'count': '10'});
    final response = await _get(uri, _cookieHeaders());
    _throwForStatus(response, uri);
    final users = Json(_decodeJson(response, uri))['users'].list;
    for (final user in users) {
      if ((user['username'].string ?? '').toLowerCase() == handle.toLowerCase()) {
        final id = user['pk'].string ?? user['id'].string ?? user['pk_id'].string;
        if (id != null && id.isNotEmpty) return id;
      }
    }
    throw ThreadsException(ThreadsErrorKind.noSuchFeed, 'user not found: $handle');
  }

  Future<ThreadsProfile> fetchProfile(String handle) async {
    _requireCookies();
    final id = await resolveUserId(handle);
    final uri = Uri.parse('$_threadsWeb/api/v1/users/$id/info/');
    final response = await _get(uri, _cookieHeaders());
    _throwForStatus(response, uri);
    final profile = threadsProfileFromUserJson(Json(_decodeJson(response, uri))['user']);
    if (profile == null) {
      throw ThreadsException(ThreadsErrorKind.noSuchFeed, 'profile missing: $handle');
    }
    return profile;
  }

  Future<List<ThreadsPost>> fetchUserThreads(String handle, {int count = threadsPostsPerAccount}) async {
    _requireCookies();
    final id = await resolveUserId(handle);
    final uri = Uri.parse('$_threadsWeb/api/v1/text_feed/$id/profile/').replace(queryParameters: {'count': '$count'});
    final response = await _get(uri, _cookieHeaders());
    _throwForStatus(response, uri);
    return parseThreadsApiFeed(_decodeJson(response, uri));
  }

  Future<List<ThreadsPost>> fetchFollowingTimeline({int limit = 40}) async {
    if (!hasBearer) {
      throw ThreadsException(ThreadsErrorKind.notConfigured, 'no bearer');
    }
    final uri = Uri.parse(
      '$_instagramApi/api/v1/feed/text_post_app_timeline/',
    ).replace(queryParameters: {'pagination_source': 'text_post_feed_following'});
    final response = await _get(uri, await _bearerHeaders());
    _throwForStatus(response, uri);
    final posts = parseThreadsApiFeed(_decodeJson(response, uri));
    return posts.take(limit).toList(growable: false);
  }

  /// Public posts for [handle] without a session.
  ///
  /// Prefers guest GraphQL (`BarcelonaProfileThreadsTabQuery`) — SSR often
  /// embeds zero `thread_items` for many profiles. HTML is still fetched once
  /// for the LSD token + user id, and used as a fallback scrape.
  Future<List<ThreadsPost>> fetchGuestAccount(String handle) async {
    final key = handle.trim().toLowerCase();
    final htmlBody = await _fetchProfileHtml(key);
    final lsd = extractThreadsLsd(htmlBody);
    final cachedId = _storedUserIds()[key];
    final userId = (cachedId != null && cachedId.isNotEmpty) ? cachedId : extractThreadsUserIdFromHtml(htmlBody, key);

    if (lsd != null && userId != null && userId.isNotEmpty) {
      await _rememberUserId(key, userId);
      try {
        final posts = await _fetchGuestGraphqlThreads(handle: key, userId: userId, lsd: lsd);
        if (posts.isNotEmpty) {
          return posts;
        }
      } on ThreadsException {
        // Fall through to SSR — doc_id rotation / transient GraphQL failures.
      }
    }

    final posts = parseThreadsSsrHtml(htmlBody, key);
    if (posts.isEmpty) {
      throw ThreadsException(ThreadsErrorKind.noSuchFeed, 'no posts for @$key (GraphQL+SSR empty)');
    }
    return posts;
  }

  Future<String> _fetchProfileHtml(String handle) async {
    final uri = Uri.parse('$_threadsWeb/@$handle');
    final response = await _get(uri, {
      'User-Agent': _safariUa,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    });
    if (response.statusCode == 404) {
      throw ThreadsException(ThreadsErrorKind.noSuchFeed, '$uri: 404');
    }
    if (response.statusCode == 429) {
      _armCooldown();
      throw ThreadsException(ThreadsErrorKind.throttled, '$uri: 429');
    }
    if (response.statusCode != 200) {
      throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<List<ThreadsPost>> _fetchGuestGraphqlThreads({
    required String handle,
    required String userId,
    required String lsd,
  }) async {
    final uri = Uri.parse('$_threadsWeb/api/graphql');
    final body = {
      'lsd': lsd,
      'doc_id': threadsGuestProfileThreadsDocId,
      'variables': jsonEncode({'userID': userId}),
    };
    final response = await _post(
      uri,
      {
        'User-Agent': _safariUa,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'X-IG-App-ID': _igAppId,
        'X-ASBD-ID': '129477',
        'X-FB-LSD': lsd,
        'X-FB-Friendly-Name': 'BarcelonaProfileThreadsTabQuery',
        'Origin': _threadsWeb,
        'Referer': '$_threadsWeb/@$handle',
      },
      body.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&'),
    );

    if (response.statusCode == 429) {
      _armCooldown();
      throw ThreadsException(ThreadsErrorKind.throttled, '$uri: 429');
    }
    if (response.statusCode != 200) {
      throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: ${response.statusCode}');
    }

    final decoded = _decodeJson(response, uri);
    final text = utf8.decode(response.bodyBytes);
    // Guest GraphQL sometimes returns the HTML shell when headers are wrong.
    if (text.trimLeft().startsWith('<!') || text.contains('<html')) {
      throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: HTML instead of JSON');
    }
    return parseThreadsGraphqlFeed(decoded);
  }

  void _requireCookies() {
    if (!hasCookies) {
      throw ThreadsException(ThreadsErrorKind.notConfigured, 'incomplete cookies');
    }
  }
}

String _randomDeviceId() {
  final r = Random.secure();
  String hex(int n) => List.generate(n, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return '${hex(4)}-${hex(2)}-${hex(2)}-${hex(2)}-${hex(6)}';
}
