import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';

/// Rows of backed-up tables that have no entity in `database/entities.dart`,
/// which is why the export used to walk straight past them.

/// One user whose reposts (`retweet_filter`) or replies (`reply_filter`) are
/// kept out of every feed.
class UserFeedFilter with ToMappable {
  final String userId;
  final String screenName;

  UserFeedFilter({required this.userId, required this.screenName});

  factory UserFeedFilter.fromMap(Map<String, Object?> map) {
    return UserFeedFilter(userId: (map['user_id'] as String?) ?? '', screenName: (map['screen_name'] as String?) ?? '');
  }

  @override
  Map<String, dynamic> toMap() => {'user_id': userId, 'screen_name': screenName};
}

/// A saved search's membership of a group, as older builds stored it.
///
/// New memberships go to [tableSubscriptionGroupMember] like everyone else's,
/// but the rows already written here are never migrated, so a backup that
/// skips them drops groupings the reader made.
class SearchGroupMember with ToMappable {
  final String group;
  final String search;

  SearchGroupMember({required this.group, required this.search});

  factory SearchGroupMember.fromMap(Map<String, Object?> map) {
    return SearchGroupMember(group: (map['group_id'] as String?) ?? '', search: (map['search_id'] as String?) ?? '');
  }

  @override
  Map<String, dynamic> toMap() => {'group_id': group, 'search_id': search};
}

/// How far the reader had got in one group's feed.
///
/// [chainCreatedAt] stays the ISO-8601 text the column holds: nothing here
/// compares it, and parsing it only to print it back risks changing it.
class FeedReadPositionRow with ToMappable {
  final String groupId;
  final String chainId;
  final String? chainCreatedAt;

  FeedReadPositionRow({required this.groupId, required this.chainId, this.chainCreatedAt});

  factory FeedReadPositionRow.fromMap(Map<String, Object?> map) {
    return FeedReadPositionRow(
      groupId: (map['group_id'] as String?) ?? '',
      chainId: (map['chain_id'] as String?) ?? '',
      chainCreatedAt: map['chain_created_at'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'group_id': groupId, 'chain_id': chainId, 'chain_created_at': chainCreatedAt};
  }
}

Future<List<T>> _readRows<T>(String table, T Function(Map<String, Object?>) fromMap) async {
  final database = await Repository.readOnly();

  return (await database.query(table)).map(fromMap).toList(growable: false);
}

Future<List<UserFeedFilter>> readRetweetFilters() => _readRows(tableRetweetFilter, UserFeedFilter.fromMap);

Future<List<UserFeedFilter>> readReplyFilters() => _readRows(tableReplyFilter, UserFeedFilter.fromMap);

Future<List<SearchGroupMember>> readSearchGroupMembers() =>
    _readRows(tableSearchSubscriptionGroupMember, SearchGroupMember.fromMap);

Future<List<FeedReadPositionRow>> readFeedReadPositions() =>
    _readRows(tableFeedReadPosition, FeedReadPositionRow.fromMap);

Future<List<ProfileNote>> readProfileNotes() => _readRows(tableProfileNote, ProfileNote.fromMap);

Future<List<Antenna>> readAntennas() => _readRows(tableAntenna, Antenna.fromMap);
