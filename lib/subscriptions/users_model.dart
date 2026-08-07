import 'dart:ui';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/group/group_model.dart';
import 'package:xta/user.dart';
import 'package:xta/utils/iterables.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';

class SubscriptionsModel extends Store<List<Subscription>> {
  static final log = Logger('SubscriptionsModel');

  final BasePrefService prefs;
  final GroupsModel groupModel;
  final Map<String, VoidCallback> _onSubscriptionsReloaded = {};

  SubscriptionsModel(this.prefs, this.groupModel) : super([]);

  void addReloadListener(String key, VoidCallback callback) {
    _onSubscriptionsReloaded[key] = callback;
  }

  void removeReloadListener(String key) {
    _onSubscriptionsReloaded.remove(key);
  }

  /// [notifyReload] is false when only the display order changed. The
  /// listeners exist to rebuild feeds whose membership moved; reordering the
  /// subscriptions screen used to drop every cached feed in the session, so
  /// the next visit to any group refetched its first page from the network.
  Future<void> reloadSubscriptions({bool notifyReload = true}) async {
    log.info('Listing subscriptions');

    await execute(() async {
      var database = await Repository.readOnly();

      String orderCustom = prefs.get(optionSubscriptionOrderCustom);
      bool orderByAscending = prefs.get(optionSubscriptionOrderByAscending);
      String orderByField = prefs.get(optionSubscriptionOrderByField);

      // Independent tables, read together. Followed Substack publications,
      // subreddits, Threads, Bluesky and Fediverse accounts are subscriptions too, so they
      // appear in this list and can be picked as group members like anyone else
      // — which is the whole reason they live in tables rather than in a preference.
      final rows = await Future.wait([
        database.query(tableSubscription),
        database.query(tableSearchSubscription),
        database.query(tableSubstackSubscription),
        database.query(tableRedditSubscription),
        database.query(tableThreadsSubscription),
        database.query(tableBlueskySubscription),
        database.query(tableMastodonSubscription),
      ]);
      List<Subscription> users = rows[0].map((e) => UserSubscription.fromMap(e)).toList();
      List<Subscription> searches = rows[1].map((e) => SearchSubscription.fromMap(e)).toList();
      List<Subscription> publications = rows[2].map((e) => SubstackSubscription.fromMap(e)).toList();
      List<Subscription> subreddits = rows[3].map((e) => RedditSubscription.fromMap(e)).toList();
      List<Subscription> threads = rows[4].map((e) => ThreadsSubscription.fromMap(e)).toList();
      List<Subscription> bluesky = rows[5].map((e) => BlueskySubscription.fromMap(e)).toList();
      List<Subscription> mastodon = rows[6].map((e) => MastodonSubscription.fromMap(e)).toList();

      List<Subscription> lst = [
        ...users,
        ...searches,
        ...publications,
        ...subreddits,
        ...threads,
        ...bluesky,
        ...mastodon,
      ];
      if (orderCustom.isEmpty) {
        return lst.sorted((a, b) {
          var one = orderByAscending ? a : b;
          var two = orderByAscending ? b : a;

          switch (orderByField) {
            case 'name':
              return one.name.toLowerCase().compareTo(two.name.toLowerCase());
            case 'screen_name':
              return one.screenName.toLowerCase().compareTo(two.screenName.toLowerCase());
            case 'created_at':
              return one.createdAt.compareTo(two.createdAt);
            default:
              return one.name.toLowerCase().compareTo(two.name.toLowerCase());
          }
        }).toList();
      } else {
        List<Subscription> newLst = [];
        for (String screenName in orderCustom.split(',')) {
          Subscription? s = lst.firstWhereOrNull((e) => e.screenName == screenName);
          if (s != null) {
            lst.removeWhere((e) => e.screenName == screenName);
            newLst.add(s);
          }
        }
        if (lst.isNotEmpty) {
          newLst.addAll(lst);
        }
        final order = newLst.map((s) => s.screenName).join(',');
        // Only when it actually changed: every pref write notifies every
        // listening widget, and this ran on every reload.
        if (prefs.get<String>(optionSubscriptionOrderCustom) != order) {
          await prefs.set(optionSubscriptionOrderCustom, order);
        }
        return newLst;
      }
    });

    if (notifyReload) {
      for (final callback in _onSubscriptionsReloaded.values) {
        callback();
      }
    }
  }

  Future<void> _toggleSearchSubscribe(SearchSubscription user, bool currentlyFollowed) async {
    var database = await Repository.writable();

    await execute(() async {
      if (currentlyFollowed) {
        await database.delete(tableSearchSubscription, where: 'id = ?', whereArgs: [user.id]);
        await database.delete(tableSearchSubscriptionGroupMember, where: 'search_id = ?', whereArgs: [user.id]);

        state.removeWhere((e) => e.id == user.id);
      } else {
        // Awaited so the reload below cannot read the table first and show the
        // search unfollowed right after the reader followed it.
        await database.insert(tableSearchSubscription, {'id': user.id});
      }

      // TODO: This is hardcore, but we need to resort the list and this is the easiest way
      await reloadSubscriptions();

      return state;
    });
  }

  Future<void> _toggleUserSubscribe(UserSubscription user, bool currentlyFollowed) async {
    var database = await Repository.writable();

    await execute(() async {
      if (currentlyFollowed) {
        await database.delete(tableSubscription, where: 'id = ?', whereArgs: [user.id]);
        await database.delete(tableSubscriptionGroupMember, where: 'profile_id = ?', whereArgs: [user.id]);

        state.removeWhere((e) => e.id == user.id);
      } else {
        // Awaited for the same reason as the search variant: the reload reads
        // this table, and losing the race showed the follow undone.
        await database.insert(tableSubscription, {
          'id': user.id,
          'screen_name': user.screenName,
          'name': user.name,
          'profile_image_url_https': user.profileImageUrlHttps,
          'verified': user.verified ? 1 : 0,
        });
      }

      // TODO: This is hardcore, but we need to resort the list and this is the easiest way
      await reloadSubscriptions();

      return state;
    });
  }

  /// Refreshes a stored subscription whose account was renamed, using the
  /// fresh profile data. The caller reloads the list when it is done.
  Future<void> repairSubscription(UserSubscription user, UserWithExtra fresh) async {
    var database = await Repository.writable();

    await database.update(
      tableSubscription,
      {
        'screen_name': fresh.screenName,
        'name': fresh.name,
        'profile_image_url_https': fresh.profileImageUrlHttps,
        'verified': (fresh.verified ?? false) ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> removeSubscriptions(List<UserSubscription> users) async {
    var database = await Repository.writable();

    await execute(() async {
      for (final user in users) {
        await database.delete(tableSubscription, where: 'id = ?', whereArgs: [user.id]);
        await database.delete(tableSubscriptionGroupMember, where: 'profile_id = ?', whereArgs: [user.id]);
      }

      await reloadSubscriptions();

      return state;
    });

    await groupModel.reloadGroups();
  }

  Future<void> toggleSubscribe(Subscription user, bool currentlyFollowed) async {
    if (user is UserSubscription) {
      await _toggleUserSubscribe(user, currentlyFollowed);
    } else if (user is SearchSubscription) {
      await _toggleSearchSubscribe(user, currentlyFollowed);
    }

    await groupModel.reloadGroups();
  }

  Future<void> toggleInFeed(Subscription user, bool wasInFeed) async {
    var database = await Repository.writable();
    await execute(() async {
      await database.update(tableSubscription, {'in_feed': wasInFeed ? 0 : 1}, where: 'id = ?', whereArgs: [user.id]);

      await reloadSubscriptions();

      return state;
    });
  }

  Future<void> changeOrderSubscriptionsBy(String? value) async {
    await execute(() async {
      await prefs.set(optionSubscriptionOrderCustom, '');
      await prefs.set(optionSubscriptionOrderByField, value ?? 'name');
      await reloadSubscriptions(notifyReload: false);

      return state;
    });
  }

  Future<void> toggleOrderSubscriptionsAscending() async {
    await execute(() async {
      await prefs.set(optionSubscriptionOrderCustom, '');
      await prefs.set(optionSubscriptionOrderByAscending, !prefs.get(optionSubscriptionOrderByAscending));
      await reloadSubscriptions(notifyReload: false);

      return state;
    });
  }
}
