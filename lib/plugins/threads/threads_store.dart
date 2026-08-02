import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/group/future_pool.dart';
import 'package:xta/plugins/threads/threads_client.dart';
import 'package:xta/plugins/threads/threads_models.dart';

/// The Threads accounts the reader follows, kept in the database so they can
/// join a subscription group like every other source.
class ThreadsAccountsStore extends Store<List<ThreadsAccount>> {
  ThreadsAccountsStore() : super(const []);

  Future<void> load() async {
    await execute(_read);
  }

  Future<List<ThreadsAccount>> _read() async {
    final database = await Repository.readOnly();
    final rows = await database.query(tableThreadsSubscription, orderBy: 'name COLLATE NOCASE');

    return rows.map(ThreadsSubscription.fromMap).map(accountOf).toList(growable: false);
  }

  Future<void> add(ThreadsAccount account) async {
    await execute(() async {
      final database = await Repository.writable();
      await database.insert(
        tableThreadsSubscription,
        subscriptionOf(account).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return _read();
    });
  }

  Future<void> remove(String handle) async {
    await execute(() async {
      final database = await Repository.writable();
      await database.delete(tableThreadsSubscription, where: 'id = ?', whereArgs: [handle]);
      // An account that is gone should not linger as a member of a group.
      await database.delete(tableSubscriptionGroupMember, where: 'profile_id = ?', whereArgs: [handle]);
      return _read();
    });
  }
}

ThreadsSubscription subscriptionOf(ThreadsAccount account) => ThreadsSubscription(
      id: account.handle,
      name: account.name,
      avatarUrl: account.avatarUrl,
      createdAt: DateTime.now(),
      inFeed: true,
    );

ThreadsAccount accountOf(ThreadsSubscription subscription) => ThreadsAccount(
      handle: subscription.id,
      name: subscription.name,
      avatarUrl: subscription.avatarUrl,
    );

/// The merged timeline of every followed account, newest first.
class ThreadsFeedStore extends Store<List<ThreadsPost>> {
  final ThreadsClient client;
  final BasePrefService prefs;
  final ThreadsAccountsStore accounts;

  ThreadsFeedStore(this.client, this.prefs, this.accounts) : super(const []);

  String get _instance => prefs.get<String>(optionPluginThreadsInstance) ?? '';

  /// Reads every account and merges them.
  ///
  /// One account failing does not empty the timeline — a handle that was
  /// renamed, or one RSSHub cannot currently serve, would otherwise take every
  /// other account's posts down with it. The error only surfaces when nothing
  /// at all could be read.
  Future<void> refresh() async {
    await execute(() async {
      if (_instance.trim().isEmpty) {
        throw ThreadsException(ThreadsErrorKind.notConfigured, 'no instance configured');
      }

      final handles = accounts.state.map((e) => e.handle).toList(growable: false);
      if (handles.isEmpty) {
        return const <ThreadsPost>[];
      }

      Object? lastError;
      final batches = await mapWithConcurrency(handles, 3, (handle) async {
        try {
          return await client.fetchAccount(_instance, handle);
        } catch (e) {
          lastError = e;
          return const <ThreadsPost>[];
        }
      });

      final posts = batches.expand((e) => e.take(threadsPostsPerAccount)).toList();
      if (posts.isEmpty && lastError != null) {
        throw lastError!;
      }

      posts.sort((a, b) => (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)));
      return posts;
    });
  }
}
