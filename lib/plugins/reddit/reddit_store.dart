import 'dart:convert';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/plugins/reddit/reddit_auth.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';

/// Subreddits the reader follows, kept in preferences — no account, so there is
/// nothing to sync.
class RedditSubredditsStore extends Store<List<String>> {
  final BasePrefService prefs;

  RedditSubredditsStore(this.prefs) : super(const []);

  Future<void> load() async {
    await execute(() async => _read());
  }

  List<String> _read() {
    final raw = prefs.get<String>(optionPluginRedditSubreddits) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      // A corrupt value should not wedge the plugin shut.
    }
    return const [];
  }

  Future<void> add(String subreddit) async {
    final name = normaliseSubreddit(subreddit);
    if (name == null) {
      return;
    }
    await execute(() async {
      final existing = _read();
      if (existing.any((e) => e.toLowerCase() == name.toLowerCase())) {
        return existing;
      }
      final next = [...existing, name];
      await prefs.set(optionPluginRedditSubreddits, jsonEncode(next));
      return next;
    });
  }

  Future<void> remove(String subreddit) async {
    await execute(() async {
      final next = _read().where((e) => e.toLowerCase() != subreddit.toLowerCase()).toList(growable: false);
      await prefs.set(optionPluginRedditSubreddits, jsonEncode(next));
      return next;
    });
  }
}

/// The merged feed: the first page of every followed subreddit, newest first.
///
/// Reddit paginates per listing, so there is no single cursor across
/// subreddits; this loads one page each and interleaves by date, which is what
/// makes a combined feed possible without inventing a cursor.
class RedditFeedStore extends Store<List<RedditPost>> {
  final RedditClient client;
  final RedditSubredditsStore subreddits;
  final BasePrefService prefs;
  final RedditAuth auth;

  RedditFeedStore(this.client, this.subreddits, this.prefs, {RedditAuth? auth})
      : auth = auth ?? RedditAuth(),
        super(const []);

  Future<void> refresh({RedditSort sort = RedditSort.hot}) async {
    await execute(() async {
      final clientId = prefs.get<String>(optionPluginRedditClientId) ?? '';
      final names = subreddits.state;
      if (names.isEmpty) {
        return const <RedditPost>[];
      }

      // Signed in: one access token for the whole refresh, rather than one per
      // subreddit. A refresh token Reddit no longer accepts means the session
      // is over, so it is dropped and the read falls back to the public route.
      String? userToken;
      final refreshToken = prefs.get<String>(optionPluginRedditRefreshToken) ?? '';
      if (refreshToken.isNotEmpty) {
        try {
          userToken = await auth.accessToken(clientId: clientId, refreshToken: refreshToken);
        } on RedditException {
          await prefs.set(optionPluginRedditRefreshToken, '');
        }
      }

      final posts = <RedditPost>[];
      for (final name in names) {
        final listing =
            await client.fetchSubreddit(name, clientId: clientId, sort: sort, limit: 15, userToken: userToken);
        posts.addAll(listing.posts.where((p) => !p.stickied));
      }

      posts.sort((a, b) {
        final left = a.createdAt;
        final right = b.createdAt;
        if (left == null || right == null) {
          return b.score.compareTo(a.score);
        }
        return right.compareTo(left);
      });

      return posts;
    });
  }
}
