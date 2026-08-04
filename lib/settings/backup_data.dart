import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/settings/backup_rows.dart';

/// The backup document: what QuaX carries between devices, and the header that
/// says what it is.
///
/// Left out on purpose: `feed_group_chunk`, `timeline_cache` and
/// `feed_group_cursor` are caches of what X already served and are dropped
/// after a week anyway, and `post_notification` was removed from the schema in
/// migration 30, so nothing has rows there to save.

/// Raised whenever an older build could misread a newer file. A reader that
/// meets a higher number refuses the file instead of applying the part of it
/// it happens to understand.
const int backupFormatVersion = 1;

/// A file written before the header existed. Every backup already on a reader's
/// phone is one of these, and it still imports exactly as it used to.
const int legacyBackupFormatVersion = 0;

bool isSupportedBackupVersion(int version) => version <= backupFormatVersion;

/// What the preview counts, and the order it lists them in.
enum BackupCategory {
  settings,
  subscriptions,
  substack,
  subreddits,
  groups,
  groupMembers,
  savedPosts,
  folders,
  likedPosts,
  filters,
  readPositions,
  accounts,
}

class SettingsData {
  final int formatVersion;
  final DateTime? exportedAt;
  final String? appVersion;
  final Map<String, dynamic>? settings;
  final List<SearchSubscription>? searchSubscriptions;
  final List<UserSubscription>? userSubscriptions;
  final List<SubstackSubscription>? substackSubscriptions;
  final List<RedditSubscription>? redditSubscriptions;
  final List<SubscriptionGroup>? subscriptionGroups;
  final List<SubscriptionGroupMember>? subscriptionGroupMembers;
  final List<SearchGroupMember>? searchGroupMembers;
  final List<SavedTweet>? tweets;
  final List<SavedTweetFolder>? savedTweetFolders;
  final List<LikedTweet>? likedTweets;
  final List<UserFeedFilter>? retweetFilters;
  final List<UserFeedFilter>? replyFilters;
  final List<FeedReadPositionRow>? feedReadPositions;
  final List<Account>? accounts;

  SettingsData({
    this.formatVersion = backupFormatVersion,
    this.exportedAt,
    this.appVersion,
    this.settings,
    this.searchSubscriptions,
    this.userSubscriptions,
    this.substackSubscriptions,
    this.redditSubscriptions,
    this.subscriptionGroups,
    this.subscriptionGroupMembers,
    this.searchGroupMembers,
    this.tweets,
    this.savedTweetFolders,
    this.likedTweets,
    this.retweetFilters,
    this.replyFilters,
    this.feedReadPositions,
    this.accounts,
  });

  factory SettingsData.fromJson(Map<String, dynamic> json) {
    return SettingsData(
      formatVersion: (json['formatVersion'] as int?) ?? legacyBackupFormatVersion,
      exportedAt: DateTime.tryParse((json['exportedAt'] as String?) ?? ''),
      appVersion: json['appVersion'] as String?,
      settings: json['settings'] as Map<String, dynamic>?,
      searchSubscriptions: _rows(json['searchSubscriptions'], SearchSubscription.fromMap),
      userSubscriptions: _rows(json['subscriptions'], UserSubscription.fromMap),
      substackSubscriptions: _rows(json['substackSubscriptions'], SubstackSubscription.fromMap),
      redditSubscriptions: _rows(json['redditSubscriptions'], RedditSubscription.fromMap),
      subscriptionGroups: _rows(json['subscriptionGroups'], SubscriptionGroup.fromMap),
      subscriptionGroupMembers: _rows(json['subscriptionGroupMembers'], SubscriptionGroupMember.fromMap),
      searchGroupMembers: _rows(json['searchGroupMembers'], SearchGroupMember.fromMap),
      tweets: _rows(json['tweets'], SavedTweet.fromMap),
      savedTweetFolders: _rows(json['savedTweetFolders'], SavedTweetFolder.fromMap),
      likedTweets: _rows(json['likedTweets'], LikedTweet.fromMap),
      retweetFilters: _rows(json['retweetFilters'], UserFeedFilter.fromMap),
      replyFilters: _rows(json['replyFilters'], UserFeedFilter.fromMap),
      feedReadPositions: _rows(json['feedReadPositions'], FeedReadPositionRow.fromMap),
      accounts: _rows(json['accounts'], Account.fromMap),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formatVersion': formatVersion,
      'exportedAt': exportedAt?.toIso8601String(),
      'appVersion': appVersion,
      'settings': settings,
      'searchSubscriptions': _maps(searchSubscriptions),
      'subscriptions': _maps(userSubscriptions),
      'substackSubscriptions': _maps(substackSubscriptions),
      'redditSubscriptions': _maps(redditSubscriptions),
      'subscriptionGroups': _maps(subscriptionGroups),
      'subscriptionGroupMembers': _maps(subscriptionGroupMembers),
      'searchGroupMembers': _maps(searchGroupMembers),
      'tweets': _maps(tweets),
      'savedTweetFolders': _maps(savedTweetFolders),
      'likedTweets': _maps(likedTweets),
      'retweetFilters': _maps(retweetFilters),
      'replyFilters': _maps(replyFilters),
      'feedReadPositions': _maps(feedReadPositions),
      'accounts': _maps(accounts),
    };
  }
}

/// A section the file does not carry stays null, which is how the import tells
/// "restore nothing here" from "restore an empty table".
List<T>? _rows<T>(Object? json, T Function(Map<String, Object?>) fromMap) {
  if (json is! List) {
    return null;
  }

  return json.whereType<Map>().map((row) => fromMap(Map<String, Object?>.from(row))).toList();
}

List<Map<String, dynamic>>? _maps(List<ToMappable>? rows) => rows?.map((row) => row.toMap()).toList();

/// What the file would restore, for the preview shown before anything is
/// written. Categories the file is silent about, and empty ones, are left out:
/// an empty result means there is nothing worth importing.
Map<BackupCategory, int> backupCounts(SettingsData data) {
  final counts = <BackupCategory, int?>{
    BackupCategory.settings: data.settings?.length,
    BackupCategory.subscriptions: _total([data.userSubscriptions, data.searchSubscriptions]),
    BackupCategory.substack: data.substackSubscriptions?.length,
    BackupCategory.subreddits: data.redditSubscriptions?.length,
    BackupCategory.groups: data.subscriptionGroups?.length,
    BackupCategory.groupMembers: _total([data.subscriptionGroupMembers, data.searchGroupMembers]),
    BackupCategory.savedPosts: data.tweets?.length,
    BackupCategory.folders: data.savedTweetFolders?.length,
    BackupCategory.likedPosts: data.likedTweets?.length,
    BackupCategory.filters: _total([data.retweetFilters, data.replyFilters]),
    BackupCategory.readPositions: data.feedReadPositions?.length,
    BackupCategory.accounts: data.accounts?.length,
  };

  return Map.fromEntries(
    counts.entries.where((entry) => (entry.value ?? 0) > 0).map((entry) => MapEntry(entry.key, entry.value!)),
  );
}

int? _total(List<List<Object>?> sections) {
  if (sections.every((rows) => rows == null)) {
    return null;
  }

  return sections.fold<int>(0, (total, rows) => total + (rows?.length ?? 0));
}

/// The rows to write, keyed by the table they belong in.
///
/// Reading positions are separate because restoring them is not obviously
/// harmless: a position from another device marks posts as already seen that
/// this reader never saw.
Map<String, List<ToMappable>> backupTables(SettingsData data, {required bool includeReadPositions}) {
  final sections = <String, List<ToMappable>?>{
    tableSearchSubscription: data.searchSubscriptions,
    tableSubscription: data.userSubscriptions,
    tableSubstackSubscription: data.substackSubscriptions,
    tableRedditSubscription: data.redditSubscriptions,
    tableSubscriptionGroup: data.subscriptionGroups,
    tableSubscriptionGroupMember: data.subscriptionGroupMembers,
    tableSearchSubscriptionGroupMember: data.searchGroupMembers,
    tableSavedTweet: data.tweets,
    tableSavedTweetFolder: data.savedTweetFolders,
    tableLikedTweet: data.likedTweets,
    tableRetweetFilter: data.retweetFilters,
    tableReplyFilter: data.replyFilters,
    tableAccounts: data.accounts,
    if (includeReadPositions) tableFeedReadPosition: data.feedReadPositions,
  };

  return Map.fromEntries(
    sections.entries.where((entry) => entry.value != null).map((entry) => MapEntry(entry.key, entry.value!)),
  );
}
