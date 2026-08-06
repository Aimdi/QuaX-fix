import 'dart:convert';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/group/future_pool.dart';
import 'package:xta/plugins/mastodon/mastodon_client.dart';
import 'package:xta/plugins/mastodon/mastodon_models.dart';

/// The instances the reader configured, home first, in the order given.
///
/// May be empty — the plugin still works, because [mastodonInstanceCandidates]
/// falls through to the built-in defaults. A corrupt stored list reads as
/// having none rather than wedging the plugin shut.
List<String> mastodonConfiguredInstances(BasePrefService prefs) {
  final home = (prefs.get<String>(optionPluginMastodonInstance) ?? '').trim();
  final raw = prefs.get<String>(optionPluginMastodonInstances) ?? '';

  var extras = const <String>[];
  if (raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        extras = decoded.whereType<String>().toList(growable: false);
      }
    } catch (_) {}
  }

  return [if (home.isNotEmpty) home, ...extras];
}

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

MastodonAccount accountOf(MastodonSubscription subscription) =>
    MastodonAccount(acct: subscription.id, name: subscription.name, avatarUrl: subscription.avatarUrl);

/// Merged timeline of every followed acct, newest first.
class MastodonFeedStore extends Store<List<MastodonPost>> {
  final MastodonClient client;
  final BasePrefService prefs;
  final MastodonAccountsStore accounts;

  MastodonFeedStore(this.client, this.prefs, this.accounts) : super(const []);

  Future<void> refresh() async {
    await execute(() async {
      final followed = accounts.state.toList(growable: false);
      if (followed.isEmpty) {
        return const <MastodonPost>[];
      }

      // Per account, not one shared home: each acct is asked for at its own
      // instance first, which is the only place guaranteed to have all of it.
      final configured = mastodonConfiguredInstances(prefs);

      Object? lastError;
      final batches = await mapWithConcurrency(followed, 3, (account) async {
        try {
          final candidates = mastodonInstanceCandidates(account.acct, configured: configured);
          return await client.fetchAccountAnywhere(candidates, account.acct, limit: mastodonPostsPerAccount);
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
