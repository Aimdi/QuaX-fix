import 'dart:convert';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xta/plugins/reddit/reddit_auth.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_read_session.dart';
import 'package:xta/plugins/reddit/reddit_sort_sheet.dart';

/// Subreddits the reader follows, kept in the database.
///
/// They used to be a JSON list in preferences, which is why a subreddit could
/// never be a member of a group. Anything still in that list is imported on
/// first load and the preference cleared.
class RedditSubredditsStore extends Store<List<String>> {
  final BasePrefService prefs;

  RedditSubredditsStore(this.prefs) : super(const []);

  Future<void> load() async {
    await execute(() async {
      await _importFromPrefs();
      return _read();
    });
  }

  Future<List<String>> _read() async {
    final database = await Repository.readOnly();
    final rows = await database.query(tableRedditSubscription, orderBy: 'name COLLATE NOCASE');

    return rows.map((e) => e['name'] as String).toList(growable: false);
  }

  Future<void> _importFromPrefs() async {
    final raw = prefs.get<String>(optionPluginRedditSubreddits) ?? '';
    if (raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final name in decoded.whereType<String>()) {
          await _write(name);
        }
      }
    } catch (_) {
      // A corrupt value should not wedge the plugin shut.
    }
    await prefs.set(optionPluginRedditSubreddits, '');
  }

  Future<void> _write(String name) async {
    final normalised = normaliseSubreddit(name);
    if (normalised == null) {
      return;
    }

    final database = await Repository.writable();
    await database.insert(
      tableRedditSubscription,
      RedditSubscription(
        id: normalised.toLowerCase(),
        name: normalised,
        createdAt: DateTime.now(),
        inFeed: true,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> add(String subreddit) async {
    await execute(() async {
      await _write(subreddit);
      return _read();
    });
  }

  Future<void> remove(String subreddit) async {
    await execute(() async {
      final id = subreddit.toLowerCase();
      final database = await Repository.writable();
      await database.delete(tableRedditSubscription, where: 'id = ?', whereArgs: [id]);
      // A subreddit that is gone should not linger as a member of a group.
      await database.delete(tableSubscriptionGroupMember, where: 'profile_id = ?', whereArgs: [id]);
      return _read();
    });
  }
}

/// The merged feed: the first page of every followed subreddit, newest first.
///
/// Reddit paginates per listing, so there is no single cursor across
/// subreddits; this loads one page each and interleaves by date, which is what
/// makes a combined feed possible without inventing a cursor.
class RedditFeedStore extends Store<List<RedditPost>> {
  static final log = Logger('RedditFeedStore');

  final RedditClient client;
  final RedditSubredditsStore subreddits;
  final BasePrefService prefs;
  final RedditAuth auth;

  RedditFeedStore(this.client, this.subreddits, this.prefs, {RedditAuth? auth})
      : auth = auth ?? RedditAuth(),
        super(const []);

  /// [sort] defaults to the reader's stored choice rather than hot, so the tab
  /// and the timeline agree about what they are showing.
  Future<void> refresh({RedditSort? sort}) async {
    await execute(() async {
      final order = sort ?? storedRedditSort(prefs);
      final names = subreddits.state;
      if (names.isEmpty) {
        return const <RedditPost>[];
      }

      // Same credential resolution as home/group interleave and listing screens.
      final session = await RedditReadSession.resolve(prefs: prefs, auth: auth);

      // Fetched together, and one at a time survivable: a single private or
      // renamed subreddit used to throw out of here and turn the whole feed
      // into an error screen, after every subreddit before it had already been
      // paid for.
      final listings = await Future.wait(names.map((name) async {
        try {
          final listing = await session.fetchSubreddit(client, name, sort: order, limit: 15);

          return listing.posts.where((p) => !p.stickied).toList();
        } catch (e) {
          log.warning('Unable to load r/$name: $e');

          return const <RedditPost>[];
        }
      }));

      final posts = listings.expand((e) => e).toList();

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
