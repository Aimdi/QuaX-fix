import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/import_data_model.dart';
import 'package:xta/settings/backup_data.dart';
import 'package:xta/settings/backup_rows.dart';

/// Tables a backup deliberately leaves out, and why.
///
/// Everything else in the schema has to be in the backup. Having no such
/// comparison is how three tables of real user data — followed stocks,
/// followed Threads accounts, and Reddit upvotes that exist nowhere but this
/// device — went unbacked-up for as long as they did: adding a table and
/// forgetting the section cost nothing and said nothing.
const _deliberatelyNotBackedUp = {
  // Caches of what a server already served, dropped after a week anyway.
  tableFeedGroupChunk,
  tableFeedGroupCursor,
  tableTimelineCache,
  // Removed from the schema in migration 30; nothing has rows here.
  tablePostNotification,
  // "This media is already on Immich" — a note about a server, not about the
  // reader. Restoring it onto a phone pointed at a *different* Immich would
  // skip uploads that never happened there, and a skipped upload is a worse
  // failure than a repeated one: Immich dedupes by checksum, so the cost of
  // leaving this out is an upload the server discards.
  tableImmichUpload,
};

/// sqflite's own bookkeeping, which is not part of this app's schema.
bool _isSqliteInternal(String name) => name.startsWith('sqlite_') || name == 'android_metadata';

Future<Set<String>> _tablesInSchema() async {
  final database = await Repository.readOnly();
  final rows = await database.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");

  return rows.map((row) => row['name'] as String).where((name) => !_isSqliteInternal(name)).toSet();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('xta_backup_coverage_test');
    await databaseFactory.setDatabasesPath(dir.path);
    await Repository().migrate();
  });

  test('every table in the schema is either backed up or deliberately not', () async {
    // The sections are what the document *can* carry, so this asks the question
    // of the shape rather than of one export's contents.
    final everySection = backupTables(
      SettingsData(
        searchSubscriptions: const [],
        userSubscriptions: const [],
        substackSubscriptions: const [],
        redditSubscriptions: const [],
        stockSubscriptions: const [],
        threadsSubscriptions: const [],
        blueskySubscriptions: const [],
        mastodonSubscriptions: const [],
        redditLocalVotes: const [],
        subscriptionGroups: const [],
        subscriptionGroupMembers: const [],
        searchGroupMembers: const [],
        tweets: const [],
        savedTweetFolders: const [],
        likedTweets: const [],
        retweetFilters: const [],
        replyFilters: const [],
        feedReadPositions: const [],
        accounts: const [],
      ),
      includeReadPositions: true,
    ).keys.toSet();

    final unaccountedFor = (await _tablesInSchema()).difference(everySection).difference(_deliberatelyNotBackedUp);

    expect(
      unaccountedFor,
      isEmpty,
      reason:
          'These tables are in the schema but no backup section writes them. Either add a section in '
          'backup_data.dart, or say why not in _deliberatelyNotBackedUp.',
    );
  });

  // `ImportDataModel` logs a rejected insert and carries on, so a section whose
  // `toMap()` does not match its columns restores nothing and says nothing. A
  // JSON round trip cannot see that — only a real insert can.
  test('the newly covered sections survive an actual import', () async {
    final createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final rows = backupTables(
      SettingsData(
        stockSubscriptions: [StockSubscription(id: 'AAPL', symbol: 'AAPL', createdAt: createdAt, inFeed: true)],
        threadsSubscriptions: [
          ThreadsSubscription(id: 'reader', name: 'Reader', avatarUrl: null, createdAt: createdAt, inFeed: true),
        ],
        redditLocalVotes: [RedditLocalVote(id: 'abc123')],
      ),
      includeReadPositions: false,
    );

    await ImportDataModel().importData(rows);

    final database = await Repository.writable();
    expect((await database.query(tableStockSubscription)).single['symbol'], 'AAPL');
    expect((await database.query(tableThreadsSubscription)).single['name'], 'Reader');
    expect((await database.query(tableRedditLocalVote)).single['id'], 'abc123');
  });

  test('nothing is excluded that no longer exists', () async {
    // An exclusion for a table that was dropped is a note about code that is
    // gone, and it hides the next real omission behind a stale name.
    final schema = await _tablesInSchema();

    expect(_deliberatelyNotBackedUp.difference(schema).difference({tablePostNotification}), isEmpty);
  });
}
