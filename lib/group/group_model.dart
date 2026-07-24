import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/subscriptions/group_mark_style.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';
import 'package:uuid/uuid.dart';

var defaultGroupIcon = '{"pack":"custom","key":"rss_feed"}';

IconData deserializeIconData(String iconData) {
  try {
    var icon = deserializeIcon(jsonDecode(iconData));
    if (icon != null) {
      return icon.data;
    }
  } catch (e) {
    // Simply ignore this exception (failed to deserialize icon)
  }

  // Use this as a default;
  return Icons.rss_feed;
}

class GroupModel extends Store<SubscriptionGroupGet> {
  final String id;

  GroupModel(this.id)
      : super(SubscriptionGroupGet(
            id: '',
            name: '',
            icon: defaultGroupIcon,
            subscriptions: [],
            includeRetweets: false,
            includeReplies: false,
            popular: false,
            custom: false,
            contentFilter: contentFilterDefault));

  Future<void> loadGroup() async {
    await execute(() async {
      var database = await Repository.readOnly();

      var group = (await database.query(tableSubscriptionGroup, where: 'id = ?', whereArgs: [id])).first;

      if (id == '-1') {
        var subscriptions =
            (await database.query(tableSubscription)).map((e) => UserSubscription.fromMap(e)).toList(growable: false);

        return SubscriptionGroupGet(
            id: '-1',
            name: 'All',
            icon: group['icon'] as String,
            subscriptions: subscriptions,
            includeReplies: _includeOverride(group['include_replies']),
            includeRetweets: _includeOverride(group['include_retweets']),
            popular: group['popular'] == 1,
            custom: group['custom'] == 1,
            contentFilter: group['content_filter'] as String? ?? contentFilterDefault);
      }

      var searchSubscriptions = (await database.rawQuery(
              'SELECT s.* FROM $tableSearchSubscription s LEFT JOIN $tableSubscriptionGroupMember sgm ON sgm.profile_id = s.id WHERE sgm.group_id = ?',
              [id]))
          .map((e) => SearchSubscription.fromMap(e))
          .toList(growable: false);

      var userSubscriptions = (await database.rawQuery(
              'SELECT s.* FROM $tableSubscription s LEFT JOIN $tableSubscriptionGroupMember sgm ON sgm.profile_id = s.id WHERE sgm.group_id = ?',
              [id]))
          .map((e) => UserSubscription.fromMap(e))
          .toList(growable: false);

      // TODO: Factory
      return SubscriptionGroupGet(
          id: group['id'] as String,
          name: group['name'] as String,
          icon: group['icon'] as String,
          subscriptions: [...userSubscriptions, ...searchSubscriptions],
          includeReplies: _includeOverride(group['include_replies']),
          includeRetweets: _includeOverride(group['include_retweets']),
          popular: group['popular'] == 1,
          custom: group['custom'] == 1,
          contentFilter: group['content_filter'] as String? ?? contentFilterDefault);
    });
  }

  // Reads the stored per-group override: null (unset) means "follow the global
  // default", otherwise the explicit on/off the user chose for this feed.
  static bool? _includeOverride(Object? value) => value == null ? null : value == 1;

  Future<void> toggleSubscriptionGroupIncludeReplies(bool? value) async {
    await execute(() async {
      (await Repository.writable())
          .rawUpdate('UPDATE $tableSubscriptionGroup SET include_replies = ? WHERE id = ?', [value, state.id]);
      return state.copyWith(includeReplies: value);
    });
  }

  Future<void> toggleSubscriptionGroupIncludeRetweets(bool? value) async {
    await execute(() async {
      (await Repository.writable())
          .rawUpdate('UPDATE $tableSubscriptionGroup SET include_retweets = ? WHERE id = ?', [value, state.id]);
      return state.copyWith(includeRetweets: value);
    });
  }

  Future<void> toggleSubscriptionGroupPopular(bool value) async {
    await execute(() async {
      (await Repository.writable())
          .rawUpdate('UPDATE $tableSubscriptionGroup SET popular = ?, custom = 0 WHERE id = ?', [value, state.id]);
      return state.copyWith(popular: value, custom: false);
    });
  }

  Future<void> toggleSubscriptionGroupCustom(bool value) async {
    await execute(() async {
      (await Repository.writable())
          .rawUpdate('UPDATE $tableSubscriptionGroup SET custom = ?, popular = 0 WHERE id = ?', [value, state.id]);
      return state.copyWith(custom: value, popular: false);
    });
  }

  Future<void> setSubscriptionGroupContentFilter(String value) async {
    await execute(() async {
      (await Repository.writable())
          .rawUpdate('UPDATE $tableSubscriptionGroup SET content_filter = ? WHERE id = ?', [value, state.id]);
      return state.copyWith(contentFilter: value);
    });
  }
}

class GroupsModel extends Store<List<SubscriptionGroup>> {
  static final log = Logger('GroupModel');

  final BasePrefService prefs;
  final Map<String, VoidCallback> _onGroupsReloaded = {};

  GroupsModel(this.prefs) : super([]);

  void addReloadListener(String key, VoidCallback callback) {
    _onGroupsReloaded[key] = callback;
  }

  void removeReloadListener(String key) {
    _onGroupsReloaded.remove(key);
  }

  bool get orderGroupsAscending => prefs.get(optionSubscriptionGroupsOrderByAscending);
  String get orderGroupsBy => prefs.get(optionSubscriptionGroupsOrderByField);

  Future<void> deleteGroup(String id) async {
    log.info('Deleting the group $id');

    await execute(() async {
      var database = await Repository.writable();

      await database.delete(tableSubscriptionGroupMember, where: 'group_id = ?', whereArgs: [id]);
      await database.delete(tableSubscriptionGroup, where: 'id = ?', whereArgs: [id]);

      return state.where((e) => e.id != id).toList();
    });
  }

  Future reloadGroups() async {
    log.info('Listing subscriptions groups');

    await execute(() async {
      var database = await Repository.readOnly();

      var orderByDirection = orderGroupsAscending ? 'COLLATE NOCASE ASC' : 'COLLATE NOCASE DESC';

      // Pinned groups always come first; within each block the chosen field
      // applies. Manual order sorts on the persisted position column.
      var orderBy = orderGroupsBy == 'position'
          ? 'g.position ${orderGroupsAscending ? 'ASC' : 'DESC'}'
          : 'g.$orderGroupsBy $orderByDirection';

      var query =
          "SELECT g.id, g.name, g.icon, g.color, g.created_at, g.pinned, g.emoji, g.mark_style, COUNT(gm.profile_id) AS number_of_members FROM $tableSubscriptionGroup g LEFT JOIN $tableSubscriptionGroupMember gm ON gm.group_id = g.id WHERE g.id != '-1' GROUP BY g.id ORDER BY g.pinned DESC, $orderBy";

      var groups = (await database.rawQuery(query)).map((e) => SubscriptionGroup.fromMap(e)).toList(growable: false);
      return groups;
    });
    for (final callback in _onGroupsReloaded.values) {
      callback();
    }
  }

  /// Makes the global replies/reposts default apply to every group again by
  /// clearing each group's own choice.
  Future<void> clearIncludeOverrides({required bool replies}) async {
    final database = await Repository.writable();
    final column = replies ? 'include_replies' : 'include_retweets';

    await database.rawUpdate('UPDATE $tableSubscriptionGroup SET $column = NULL');
    await reloadGroups();
  }

  Future<List<SubscriptionGroupMember>> listGroupMembers() async {
    var database = await Repository.readOnly();

    return (await database.query(tableSubscriptionGroupMember))
        .map((e) => SubscriptionGroupMember(group: e['group_id'] as String, profile: e['profile_id'] as String))
        .toList(growable: false);
  }

  Future<List<String>> listGroupsForUser(String user) async {
    var database = await Repository.readOnly();

    return (await database.query(tableSubscriptionGroupMember,
            columns: ['group_id'], where: 'profile_id = ?', whereArgs: [user]))
        .map((e) => e['group_id'] as String)
        .toList(growable: false);
  }

  Future saveUserGroupMembership(String user, List<String> memberships) async {
    var database = await Repository.writable();

    var batch = database.batch();

    // First, clear all the memberships for the user
    batch.delete(tableSubscriptionGroupMember, where: 'profile_id = ?', whereArgs: [user]);

    // Then add all the new memberships
    for (var group in memberships) {
      batch.insert(tableSubscriptionGroupMember, {'group_id': group, 'profile_id': user});
    }

    await batch.commit();
    await reloadGroups();
  }

  Future<SubscriptionGroupEdit> loadGroupEdit(String? id) async {
    var database = await Repository.readOnly();

    if (id == null) {
      return SubscriptionGroupEdit(
        id: null,
        name: '',
        icon: defaultGroupIcon,
        color: null,
        members: <String>{},
        emoji: null,
        markStyle: GroupMarkStyle.auto,
      );
    }

    var group = await database.query(tableSubscriptionGroup, where: 'id = ?', whereArgs: [id]);
    if (group.isEmpty) {
      return SubscriptionGroupEdit(
        id: null,
        name: '',
        icon: defaultGroupIcon,
        color: null,
        members: <String>{},
        emoji: null,
        markStyle: GroupMarkStyle.auto,
      );
    }

    var members = (await database.query(tableSubscriptionGroupMember, where: 'group_id = ?', whereArgs: [id]))
        .map((e) => e['profile_id'] as String)
        .toSet();

    return SubscriptionGroupEdit(
      id: group.first['id'] as String,
      name: group.first['name'] as String,
      icon: group.first['icon'] as String,
      color: group.first['color'] == null ? null : Color(group.first['color'] as int),
      members: members,
      emoji: group.first['emoji'] as String?,
      markStyle: GroupMarkStyle.coerce(group.first['mark_style']),
    );
  }

  Future saveGroup(
    String? id,
    String name,
    String icon,
    Color? color,
    Set<String> subscriptions, {
    String? emoji,
    int markStyle = GroupMarkStyle.auto,
  }) async {
    await execute(() async {
      var database = await Repository.writable();

      // First insert or update the subscription group details
      if (id == null) {
        id = const Uuid().v4();

        // Leave the reply/retweet filters null so a new group follows the
        // global default instead of the column's own "on" default.
        await database.insert(tableSubscriptionGroup, {
          'id': id,
          'name': name,
          'color': color?.toARGB32(),
          'icon': icon,
          'include_replies': null,
          'include_retweets': null,
          'emoji': emoji,
          'mark_style': markStyle,
        });
      } else {
        await database.update(
            tableSubscriptionGroup,
            {
              'name': name,
              'color': color?.toARGB32(),
              'icon': icon,
              'emoji': emoji,
              'mark_style': markStyle,
            },
            where: 'id = ?',
            whereArgs: [id]);
      }

      // Then clear out any existing subscriptions for the group and add our new set
      await database.delete(tableSubscriptionGroupMember, where: 'group_id = ?', whereArgs: [id]);

      var batch = database.batch();
      for (var subscription in subscriptions) {
        batch.insert(tableSubscriptionGroupMember, {'group_id': id, 'profile_id': subscription});
      }

      await batch.commit(noResult: true);
      await reloadGroups();

      // TODO: Replace the group in the state instead
      return state;
    });
  }

  Future<void> toggleGroupPinned(String id, bool pinned) async {
    var database = await Repository.writable();
    await database.update(tableSubscriptionGroup, {'pinned': pinned ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    await reloadGroups();
  }

  /// Persists a manual order: each group's position becomes its index in [ids].
  Future<void> saveGroupPositions(List<String> ids) async {
    var database = await Repository.writable();
    var batch = database.batch();
    for (var (i, id) in ids.indexed) {
      batch.update(tableSubscriptionGroup, {'position': i}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
    await reloadGroups();
  }

  /// Moves every member of [sourceId] into [targetId] (skipping duplicates),
  /// then deletes the now-empty source group.
  Future<void> mergeGroups(String sourceId, String targetId) async {
    var database = await Repository.writable();
    await database.rawInsert(
        'INSERT OR IGNORE INTO $tableSubscriptionGroupMember (group_id, profile_id) '
        'SELECT ?, profile_id FROM $tableSubscriptionGroupMember WHERE group_id = ?',
        [targetId, sourceId]);
    await database.delete(tableSubscriptionGroupMember, where: 'group_id = ?', whereArgs: [sourceId]);
    await database.delete(tableSubscriptionGroup, where: 'id = ?', whereArgs: [sourceId]);
    await reloadGroups();
  }

  void changeOrderSubscriptionGroupsBy(String? value) async {
    await prefs.set(optionSubscriptionGroupsOrderByField, value ?? 'name');
    await reloadGroups();
  }

  void toggleOrderSubscriptionGroupsAscending() async {
    await prefs.set(optionSubscriptionGroupsOrderByAscending, !orderGroupsAscending);
    await reloadGroups();
  }
}