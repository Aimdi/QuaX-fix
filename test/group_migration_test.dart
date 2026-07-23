import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Creates a database matching the schema at version 33 (only the tables the
/// migration path from 33 to 34 touches), with a few groups to backfill.
Future<void> _createV33Fixture() async {
  final db = await databaseFactory.openDatabase(databaseName,
      options: OpenDatabaseOptions(
          version: 33,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE $tableSubscriptionGroup ('
                'id VARCHAR PRIMARY KEY, name VARCHAR NOT NULL, icon VARCHAR NOT NULL, '
                'created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, include_replies BOOLEAN, '
                'include_retweets BOOLEAN, color INT, popular BOOLEAN DEFAULT 0, '
                "custom BOOLEAN DEFAULT 0, content_filter VARCHAR DEFAULT 'default')");
            await db.execute('CREATE TABLE $tableFeedGroupCursor '
                '(id INTEGER PRIMARY KEY, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');
            await db.execute('CREATE TABLE $tableFeedGroupChunk '
                '(cursor_id INTEGER NOT NULL, hash VARCHAR NOT NULL, cursor_top VARCHAR, '
                'cursor_bottom VARCHAR, response VARCHAR, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');

            await db.insert(tableSubscriptionGroup, {'id': '-1', 'name': 'All', 'icon': 'rss_feed'});
            await db.insert(tableSubscriptionGroup, {'id': 'b', 'name': 'beta', 'icon': 'x'});
            await db.insert(tableSubscriptionGroup, {'id': 'a', 'name': 'Alpha', 'icon': 'x'});
          }));
  await db.close();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('quax_migration_test');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  test('migration 34 adds pinned and position, backfilling alphabetical order', () async {
    await _createV33Fixture();

    await Repository().migrate();

    final db = await databaseFactory.openDatabase(databaseName);
    final rows = await db.query(tableSubscriptionGroup);
    final byName = {for (final r in rows) r['name'] as String: r};

    expect(byName['Alpha']!['position'], 0);
    expect(byName['beta']!['position'], 1);
    expect(rows.every((r) => r['pinned'] == 0), isTrue);
    await db.close();
  });
}
