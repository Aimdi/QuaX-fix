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

  ThreadsDirectClient(
    this.prefs, {
    http.Client? httpClient,
    this.minGap = const Duration(seconds: 2),
  }) : httpClient = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 25);

  Map<String, String> get cookies => parseThreadsCookieHeader(prefs.get<String>(optionPluginThreadsDirectCookies) ?? '');

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

  Future<void> _pace() async {
    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      throw ThreadsException(ThreadsErrorKind.sessionSuspended, 'cooldown until $_cooldownUntil');
    }
    if (_lastRequestAt != null) {
      final wait = minGap - now.difference(_lastRequestAt!);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequestAt = DateTime.now();
  }

  void _armCooldown() {
    _cooldownUntil = DateTime.now().add(const Duration(minutes: 30));
  }

  Future<http.Response> _get(Uri uri, Map<String, String> headers) async {
    await _pace();
    try {
      return await httpClient.get(uri, headers: headers).timeout(_timeout);
    } catch (e) {
      throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: $e');
    }
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

  Future<String> resolveUserId(String handle) async {
    _requireCookies();
    final uri = Uri.parse('$_threadsWeb/api/v1/users/search/').replace(queryParameters: {
      'q': handle,
      'count': '10',
    });
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
    final uri = Uri.parse('$_threadsWeb/api/v1/text_feed/$id/profile/').replace(queryParameters: {
      'count': '$count',
    });
    final response = await _get(uri, _cookieHeaders());
    _throwForStatus(response, uri);
    return parseThreadsApiFeed(_decodeJson(response, uri));
  }

  Future<List<ThreadsPost>> fetchFollowingTimeline({int limit = 40}) async {
    if (!hasBearer) {
      throw ThreadsException(ThreadsErrorKind.notConfigured, 'no bearer');
    }
    final uri = Uri.parse('$_instagramApi/api/v1/feed/text_post_app_timeline/').replace(queryParameters: {
      'pagination_source': 'text_post_feed_following',
    });
    final response = await _get(uri, await _bearerHeaders());
    _throwForStatus(response, uri);
    final posts = parseThreadsApiFeed(_decodeJson(response, uri));
    return posts.take(limit).toList(growable: false);
  }

  /// Public profile HTML with a mobile Safari UA — no session required.
  Future<List<ThreadsPost>> fetchGuestAccount(String handle) async {
    final uri = Uri.parse('$_threadsWeb/@$handle');
    await _pace();
    final http.Response response;
    try {
      response = await httpClient.get(uri, headers: {
        'User-Agent': _safariUa,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(_timeout);
    } catch (e) {
      throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: $e');
    }
    if (response.statusCode == 404) {
      throw ThreadsException(ThreadsErrorKind.noSuchFeed, '$uri: 404');
    }
    if (response.statusCode == 429) {
      throw ThreadsException(ThreadsErrorKind.throttled, '$uri: 429');
    }
    if (response.statusCode != 200) {
      throw ThreadsException(ThreadsErrorKind.unreachable, '$uri: ${response.statusCode}');
    }
    final posts = parseThreadsSsrHtml(utf8.decode(response.bodyBytes), handle);
    if (posts.isEmpty) {
      throw ThreadsException(ThreadsErrorKind.noSuchFeed, 'no thread_items in SSR for @$handle');
    }
    return posts;
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
