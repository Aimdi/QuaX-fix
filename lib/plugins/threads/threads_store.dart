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

/// How long a handle's posts are reused before Meta is asked for them again.
///
/// The Threads tab, the home timeline and every group feed read the same
/// accounts. Without this, opening a group after the tab asked Meta for all of
/// them a second time — with the reader's own session, which is the one thing
/// this plugin has to spend sparingly. Meta bans accounts that behave like
/// scripts, and the surest way to look like one is to ask for the same thing
/// over and over.
const Duration kThreadsCacheTtl = Duration(minutes: 10);

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

ThreadsAccount accountOf(ThreadsSubscription subscription) =>
    ThreadsAccount(handle: subscription.id, name: subscription.name, avatarUrl: subscription.avatarUrl);

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
  Future<void> refresh({bool force = false}) async {
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

      return postsFor(handles, forceRefresh: force);
    });
  }

  /// Posts for [handles], newest first, through whichever source is configured.
  ///
  /// Public because the Threads tab is no longer the only place these are
  /// shown: group feeds and the home timeline mix them in too, and all three
  /// have to agree about which source a session, an RSSHub instance or neither
  /// implies. Deciding that in one place is what stops the tab working while a
  /// group shows nothing.
  Future<List<ThreadsPost>> postsFor(List<String> handles, {bool forceRefresh = false}) async {
    if (handles.isEmpty) {
      return const [];
    }

    _forgetOnCredentialChange();
    return _mergeAccounts(handles, _fetcher(), forceRefresh: forceRefresh);
  }

  /// Which route answers, given what the reader has configured.
  Future<List<ThreadsPost>> Function(String handle) _fetcher() {
    if (direct.hasCookies) {
      return direct.fetchUserThreads;
    }
    if (_instance.trim().isNotEmpty) {
      return (handle) => client.fetchAccount(_instance, handle);
    }
    return direct.fetchGuestAccount;
  }

  /// What each handle last returned, and when.
  final Map<String, ({DateTime at, List<ThreadsPost> posts})> _cache = {};
  String? _credentials;

  /// A change of session, or of RSSHub instance, means a different Threads is
  /// answering — so what was cached under the old one is not an answer to the
  /// new question.
  void _forgetOnCredentialChange() {
    final current = [
      prefs.get<String>(optionPluginThreadsDirectCookies) ?? '',
      prefs.get<String>(optionPluginThreadsDirectBearer) ?? '',
      _instance,
    ].join(' ');

    if (_credentials != current) {
      _credentials = current;
      _cache.clear();
    }
  }

  List<ThreadsPost>? _fresh(String handle) {
    final entry = _cache[handle];
    if (entry == null || DateTime.now().difference(entry.at) > kThreadsCacheTtl) {
      return null;
    }

    return entry.posts;
  }

  Future<List<ThreadsPost>> _mergeAccounts(
    List<String> handles,
    Future<List<ThreadsPost>> Function(String handle) fetch, {
    bool forceRefresh = false,
  }) async {
    Object? lastError;
    final batches = await mapWithConcurrency(handles, 2, (handle) async {
      if (!forceRefresh) {
        if (_fresh(handle) case final cached?) {
          return cached;
        }
      }

      try {
        final posts = await fetch(handle);
        _cache[handle] = (at: DateTime.now(), posts: posts);
        return posts;
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
