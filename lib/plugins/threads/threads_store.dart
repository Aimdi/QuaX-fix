import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/group/future_pool.dart';
import 'package:xta/plugins/threads/threads_client.dart';
import 'package:xta/plugins/threads/threads_direct_client.dart';
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

/// The merged timeline of every followed account, newest first — or the Meta
/// Following feed when a Bearer session is pasted.
class ThreadsFeedStore extends Store<List<ThreadsPost>> {
  final ThreadsClient client;
  final ThreadsDirectClient direct;
  final BasePrefService prefs;
  final ThreadsAccountsStore accounts;

  ThreadsFeedStore(this.client, this.direct, this.prefs, this.accounts) : super(const []);

  String get _instance => prefs.get<String>(optionPluginThreadsInstance) ?? '';

  /// Reads the best available source (see docs/specs/threads-direct.md).
  Future<void> refresh() async {
    await execute(() async {
      if (direct.hasBearer) {
        return await direct.fetchFollowingTimeline();
      }

      final handles = accounts.state.map((e) => e.handle).toList(growable: false);
      if (handles.isEmpty) {
        if (direct.hasCookies || _instance.trim().isNotEmpty) {
          return const <ThreadsPost>[];
        }
        throw ThreadsException(ThreadsErrorKind.notConfigured, 'no accounts or session');
      }

      if (direct.hasCookies) {
        return _mergeAccounts(handles, (h) => direct.fetchUserThreads(h));
      }
      if (_instance.trim().isNotEmpty) {
        return _mergeAccounts(handles, (h) => client.fetchAccount(_instance, h));
      }
      return _mergeAccounts(handles, (h) => direct.fetchGuestAccount(h));
    });
  }

  Future<List<ThreadsPost>> _mergeAccounts(
    List<String> handles,
    Future<List<ThreadsPost>> Function(String handle) fetch,
  ) async {
    Object? lastError;
    final batches = await mapWithConcurrency(handles, 2, (handle) async {
      try {
        return await fetch(handle);
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
  }
}
