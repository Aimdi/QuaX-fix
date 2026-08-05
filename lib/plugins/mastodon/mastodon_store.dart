import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/group/future_pool.dart';
import 'package:xta/plugins/mastodon/mastodon_client.dart';
import 'package:xta/plugins/mastodon/mastodon_models.dart';

/// Fediverse accounts the reader follows locally, kept in the database.
class MastodonAccountsStore extends Store<List<MastodonAccount>> {
  MastodonAccountsStore() : super(const []);

  Future<void> load() async {
    await execute(_read);
  }

  Future<List<MastodonAccount>> _read() async {
    final database = await Repository.readOnly();
    final rows = await database.query(tableMastodonSubscription, orderBy: 'name COLLATE NOCASE');

    return rows.map(MastodonSubscription.fromMap).map(accountOf).toList(growable: false);
  }

  Future<void> add(MastodonAccount account) async {
    await execute(() async {
      final database = await Repository.writable();
      await database.insert(
        tableMastodonSubscription,
        subscriptionOf(account).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return _read();
    });
  }

  Future<void> remove(String acct) async {
    await execute(() async {
      final database = await Repository.writable();
      await database.delete(tableMastodonSubscription, where: 'id = ?', whereArgs: [acct]);
      await database.delete(tableSubscriptionGroupMember, where: 'profile_id = ?', whereArgs: [acct]);
      return _read();
    });
  }

  bool follows(String acct) => state.any((e) => e.acct == acct);
}

MastodonSubscription subscriptionOf(MastodonAccount account) => MastodonSubscription(
      id: account.acct,
      name: account.name,
      avatarUrl: account.avatarUrl,
      createdAt: DateTime.now(),
      inFeed: true,
    );

MastodonAccount accountOf(MastodonSubscription subscription) => MastodonAccount(
      acct: subscription.id,
      name: subscription.name,
      avatarUrl: subscription.avatarUrl,
    );

/// Merged timeline of every followed acct, newest first.
class MastodonFeedStore extends Store<List<MastodonPost>> {
  final MastodonClient client;
  final BasePrefService prefs;
  final MastodonAccountsStore accounts;

  MastodonFeedStore(this.client, this.prefs, this.accounts) : super(const []);

  String get _instance => prefs.get<String>(optionPluginMastodonInstance) ?? '';

  Future<void> refresh() async {
    await execute(() async {
      final instance = normaliseMastodonInstance(_instance);
      if (instance == null) {
        throw MastodonException(MastodonErrorKind.notConfigured, 'no instance configured');
      }

      final followed = accounts.state.toList(growable: false);
      if (followed.isEmpty) {
        return const <MastodonPost>[];
      }

      Object? lastError;
      final batches = await mapWithConcurrency(followed, 3, (account) async {
        try {
          return await client.fetchAccount(instance, account.acct, limit: mastodonPostsPerAccount);
        } catch (e) {
          lastError = e;
          return const <MastodonPost>[];
        }
      });

      final posts = batches.expand((e) => e.take(mastodonPostsPerAccount)).toList();
      if (posts.isEmpty && lastError != null) {
        throw lastError!;
      }

      posts.sort((a, b) => (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)));
      return posts;
    });
  }
}
