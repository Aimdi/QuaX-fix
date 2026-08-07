import 'package:flutter_triple/flutter_triple.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/group/future_pool.dart';
import 'package:xta/plugins/bluesky/bluesky_client.dart';
import 'package:xta/plugins/bluesky/bluesky_models.dart';

/// The Bluesky accounts the reader follows locally, kept in the database.
class BlueskyAccountsStore extends Store<List<BlueskyAccount>> {
  BlueskyAccountsStore() : super(const []);

  Future<void> load() async {
    await execute(_read);
  }

  Future<List<BlueskyAccount>> _read() async {
    final database = await Repository.readOnly();
    final rows = await database.query(tableBlueskySubscription, orderBy: 'name COLLATE NOCASE');

    return rows.map(BlueskySubscription.fromMap).map(accountOf).toList(growable: false);
  }

  Future<void> add(BlueskyAccount account) async {
    await execute(() async {
      final database = await Repository.writable();
      await database.insert(
        tableBlueskySubscription,
        subscriptionOf(account).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return _read();
    });
  }

  /// Inserts many local follows in one write pass. Skips handles already known.
  ///
  /// Returns how many rows were newly written — used by the import progress UI.
  Future<int> addMany(Iterable<BlueskyAccount> accounts) async {
    final existing = {for (final account in state) account.handle.toLowerCase()};
    final fresh = <BlueskyAccount>[];
    for (final account in accounts) {
      final handle = account.handle.trim();
      if (handle.isEmpty) {
        continue;
      }
      final key = handle.toLowerCase();
      if (!existing.add(key)) {
        continue;
      }
      fresh.add(account);
    }

    if (fresh.isEmpty) {
      return 0;
    }

    final database = await Repository.writable();
    final batch = database.batch();
    for (final account in fresh) {
      batch.insert(
        tableBlueskySubscription,
        subscriptionOf(account).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    update(await _read());
    return fresh.length;
  }

  Future<void> remove(String handle) async {
    await execute(() async {
      final database = await Repository.writable();
      await database.delete(tableBlueskySubscription, where: 'id = ?', whereArgs: [handle]);
      await database.delete(tableSubscriptionGroupMember, where: 'profile_id = ?', whereArgs: [handle]);
      return _read();
    });
  }

  bool follows(String handle) {
    final key = handle.trim().toLowerCase();
    return state.any((e) => e.handle.toLowerCase() == key);
  }
}

BlueskySubscription subscriptionOf(BlueskyAccount account) => BlueskySubscription(
      id: account.handle,
      name: account.name,
      avatarUrl: account.avatarUrl,
      createdAt: DateTime.now(),
      inFeed: true,
    );

BlueskyAccount accountOf(BlueskySubscription subscription) => BlueskyAccount(
      handle: subscription.id,
      name: subscription.name,
      avatarUrl: subscription.avatarUrl,
    );

/// The merged timeline of every followed account, newest first.
class BlueskyFeedStore extends Store<List<BlueskyPost>> {
  final BlueskyClient client;
  final BlueskyAccountsStore accounts;

  BlueskyFeedStore(this.client, this.accounts) : super(const []);

  /// Reads every account and merges them.
  ///
  /// One account failing does not empty the timeline — a renamed handle, or a
  /// temporary AppView error, would otherwise take every other account's posts
  /// down with it. The error only surfaces when nothing at all could be read.
  Future<void> refresh() async {
    await execute(() async {
      final followed = accounts.state.toList(growable: false);
      if (followed.isEmpty) {
        return const <BlueskyPost>[];
      }

      Object? lastError;
      final batches = await mapWithConcurrency(followed, 3, (account) async {
        try {
          final page = await client.getAuthorFeed(account.actor, limit: blueskyPostsPerAccount);
          return page.posts;
        } catch (e) {
          lastError = e;
          return const <BlueskyPost>[];
        }
      });

      final posts = batches.expand((e) => e.take(blueskyPostsPerAccount)).toList();
      if (posts.isEmpty && lastError != null) {
        throw lastError!;
      }

      posts.sort((a, b) => (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)));
      return posts;
    });
  }
}
