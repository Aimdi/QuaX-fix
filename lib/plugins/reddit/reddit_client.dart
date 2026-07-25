import 'dart:convert';

import 'package:http/http.dart' as http;

/// How a Reddit request failed, in terms the user can act on.
enum RedditErrorKind {
  /// No client id stored yet.
  notConfigured,

  /// Reddit rejected the client id (401).
  unauthorized,

  /// Reddit refused the request (403) — commonly its network-level blocking
  /// rather than anything wrong with the app.
  blocked,

  /// Subreddit does not exist, is private, or was banned (404).
  notFound,

  /// Too many requests (429).
  rateLimited,

  /// Answered, but not with the JSON the API documents.
  badResponse,

  /// Could not reach Reddit at all.
  network,
}

class RedditException implements Exception {
  final RedditErrorKind kind;
  final String detail;

  const RedditException(this.kind, this.detail);

  @override
  String toString() => 'RedditException($kind): $detail';
}

/// One post in a listing. Only what a reader needs; every field is parsed
/// defensively because Reddit adds and removes keys without notice.
class RedditPost {
  final String id;
  final String title;
  final String subreddit;
  final String? author;
  final int score;
  final int commentCount;
  final DateTime? createdAt;

  /// Path on reddit.com, e.g. `/r/dartlang/comments/abc123/title/`.
  final String permalink;

  /// What the post points at: the article for a link post, the permalink for a
  /// self post.
  final String? url;

  final bool isSelf;
  final String? selfText;
  final bool over18;
  final bool stickied;
  final String? thumbnail;

  const RedditPost({
    required this.id,
    required this.title,
    required this.subreddit,
    required this.permalink,
    this.author,
    this.score = 0,
    this.commentCount = 0,
    this.createdAt,
    this.url,
    this.isSelf = false,
    this.selfText,
    this.over18 = false,
    this.stickied = false,
    this.thumbnail,
  });

  /// A thumbnail worth showing; Reddit uses sentinels like `self` and `default`
  /// where there is no image.
  String? get thumbnailUrl {
    final value = thumbnail;
    if (value == null || !value.startsWith('http')) {
      return null;
    }
    return value;
  }

  static RedditPost? fromChild(Map<String, dynamic> child) {
    if (child['kind'] != 't3') {
      return null;
    }
    final data = child['data'];
    if (data is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(data);

    final id = map['id'] as String?;
    final title = map['title'] as String?;
    if (id == null || id.isEmpty || title == null) {
      return null;
    }

    final created = map['created_utc'];
    return RedditPost(
      id: id,
      title: title,
      subreddit: map['subreddit'] as String? ?? '',
      permalink: map['permalink'] as String? ?? '/comments/$id',
      author: map['author'] as String?,
      score: (map['score'] as num?)?.toInt() ?? 0,
      commentCount: (map['num_comments'] as num?)?.toInt() ?? 0,
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch((created * 1000).round(), isUtc: true).toLocal()
          : null,
      url: map['url'] as String?,
      isSelf: map['is_self'] == true,
      selfText: (map['selftext'] as String?)?.trim(),
      over18: map['over_18'] == true,
      stickied: map['stickied'] == true,
      thumbnail: map['thumbnail'] as String?,
    );
  }
}

class RedditListing {
  final List<RedditPost> posts;

  /// Reddit's pagination cursor; null when there is no further page.
  final String? after;

  const RedditListing({required this.posts, this.after});
}

/// Sort orders a subreddit listing supports.
enum RedditSort { hot, newest, top, rising }

String redditSortPath(RedditSort sort) => switch (sort) {
      RedditSort.hot => 'hot',
      RedditSort.newest => 'new',
      RedditSort.top => 'top',
      RedditSort.rising => 'rising',
    };

/// Read-only Reddit client using app-only OAuth, so nobody has to log in.
///
/// Reddit stopped serving its `.json` endpoints to unauthenticated clients, so
/// even an account-free reader needs a token. The `installed_client` grant gives
/// one without any user account: it authenticates the *app*, identified by a
/// client id the user creates once, and a device id that deliberately says "do
/// not track".
class RedditClient {
  final http.Client httpClient;

  RedditClient({http.Client? httpClient, DateTime Function()? clock})
      : httpClient = httpClient ?? http.Client(),
        _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  static const _tokenEndpoint = 'https://www.reddit.com/api/v1/access_token';
  static const _apiBase = 'https://oauth.reddit.com';
  static const _timeout = Duration(seconds: 20);

  /// Reddit asks for a descriptive agent and throttles generic ones harder.
  static const userAgent = 'android:com.teskann.quax:1.0 (read-only, account-free)';

  /// Reddit's documented value for "do not associate this with a device".
  static const deviceId = 'DO_NOT_TRACK_THIS_DEVICE';

  String? _token;
  DateTime? _tokenExpiry;

  /// Whether a usable token is already cached.
  bool get hasToken => _token != null && (_tokenExpiry?.isAfter(_now()) ?? false);

  void forgetToken() {
    _token = null;
    _tokenExpiry = null;
  }

  /// Fetches (and caches) an app-only token.
  Future<String> _authorize(String clientId) async {
    if (hasToken) {
      return _token!;
    }
    if (clientId.trim().isEmpty) {
      throw const RedditException(RedditErrorKind.notConfigured, 'Missing client id');
    }

    final response = await _send(() => httpClient.post(
          Uri.parse(_tokenEndpoint),
          headers: {
            'Authorization': 'Basic ${base64Encode(utf8.encode('${clientId.trim()}:'))}',
            'User-Agent': userAgent,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: 'grant_type=https://oauth.reddit.com/grants/installed_client&device_id=$deviceId',
        ));

    if (response.statusCode != 200) {
      throw _errorFor(response);
    }

    final decoded = _decode(response);
    final token = decoded['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const RedditException(RedditErrorKind.badResponse, 'No access_token in the token response');
    }

    final expiresIn = (decoded['expires_in'] as num?)?.toInt() ?? 3600;
    _token = token;
    // Expire a minute early so a request in flight cannot land on a dead token.
    _tokenExpiry = _now().add(Duration(seconds: expiresIn - 60));
    return token;
  }

  /// Posts from one subreddit.
  Future<RedditListing> fetchSubreddit(
    String subreddit, {
    required String clientId,
    RedditSort sort = RedditSort.hot,
    int limit = 25,
    String? after,
  }) async {
    final name = normaliseSubreddit(subreddit);
    if (name == null) {
      throw RedditException(RedditErrorKind.notFound, 'Not a subreddit name: $subreddit');
    }

    final token = await _authorize(clientId);
    final uri = Uri.parse('$_apiBase/r/$name/${redditSortPath(sort)}').replace(queryParameters: {
      'limit': '$limit',
      // Gives real characters instead of HTML entities in titles and text.
      'raw_json': '1',
      if (after != null && after.isNotEmpty) 'after': after,
    });

    final response = await _send(() => httpClient.get(uri, headers: {
          'Authorization': 'Bearer $token',
          'User-Agent': userAgent,
        }));

    if (response.statusCode == 401) {
      // The cached token was rejected; drop it so the next attempt re-authorises.
      forgetToken();
    }
    if (response.statusCode != 200) {
      throw _errorFor(response);
    }

    return _listingFrom(_decode(response));
  }

  /// Confirms a client id works, used by the settings screen.
  Future<bool> verify({required String clientId}) async {
    forgetToken();
    await _authorize(clientId);
    return true;
  }

  RedditListing _listingFrom(Map<String, dynamic> decoded) {
    final data = decoded['data'];
    if (data is! Map) {
      throw const RedditException(RedditErrorKind.badResponse, 'Listing has no data');
    }

    final children = data['children'];
    final posts = <RedditPost>[];
    if (children is List) {
      for (final child in children) {
        if (child is Map) {
          final post = RedditPost.fromChild(Map<String, dynamic>.from(child));
          if (post != null) {
            posts.add(post);
          }
        }
      }
    }

    final after = data['after'];
    return RedditListing(posts: posts, after: after is String && after.isNotEmpty ? after : null);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on RedditException {
      rethrow;
    } catch (e) {
      throw RedditException(RedditErrorKind.network, '$e');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Fall through to the shared error below.
    }
    throw const RedditException(RedditErrorKind.badResponse, 'Response was not a JSON object');
  }

  RedditException _errorFor(http.Response response) {
    final detail = 'HTTP ${response.statusCode}';
    return switch (response.statusCode) {
      401 => RedditException(RedditErrorKind.unauthorized, detail),
      403 => RedditException(RedditErrorKind.blocked, detail),
      404 => RedditException(RedditErrorKind.notFound, detail),
      429 => RedditException(RedditErrorKind.rateLimited, detail),
      _ => RedditException(RedditErrorKind.badResponse, detail),
    };
  }
}

final RegExp _subredditPattern = RegExp(r'^[A-Za-z0-9_]{2,21}$');

/// Pulls a subreddit name out of whatever the user pasted: `dartlang`,
/// `r/dartlang`, `/r/dartlang/`, or a full reddit.com URL.
String? normaliseSubreddit(String raw) {
  var text = raw.trim();
  if (text.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(text);
  if (uri != null && uri.host.isNotEmpty) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final index = segments.indexOf('r');
    if (index == -1 || index + 1 >= segments.length) {
      return null;
    }
    text = segments[index + 1];
  }

  text = text.replaceFirst(RegExp(r'^/?r/', caseSensitive: false), '');
  text = text.replaceAll(RegExp(r'^/+|/+$'), '');

  return _subredditPattern.hasMatch(text) ? text : null;
}
