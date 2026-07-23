import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/import_data_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('quax_repro_test');
    await databaseFactory.setDatabasesPath(dir.path);
    await Repository().migrate();
  });

  test('create group then reload works on a fresh migrated DB', () async {
    final prefs = PrefServiceCache(cache: {
      optionSubscriptionGroupsOrderByField: 'name',
      optionSubscriptionGroupsOrderByAscending: true,
    });
    final model = GroupsModel(prefs);

    await model.saveGroup(null, 'Test Group', defaultGroupIcon, null, <String>{});
    await model.reloadGroups();

    expect(model.state.map((g) => g.name), contains('Test Group'));
  });

  test('importing an old-format backup brings groups back', () async {
    final prefs = PrefServiceCache(cache: {
      optionSubscriptionGroupsOrderByField: 'name',
      optionSubscriptionGroupsOrderByAscending: true,
    });
    final model = GroupsModel(prefs);

    // Old exports have no pinned/position keys.
    final oldGroup = SubscriptionGroup.fromMap({
      'id': 'legacy-1',
      'name': 'Legacy Group',
      'icon': 'rss',
      'color': null,
      'created_at': '2024-01-01T00:00:00.000',
    });

    await ImportDataModel().importData({
      tableSubscriptionGroup: [oldGroup],
      tableSubscriptionGroupMember: [SubscriptionGroupMember(group: 'legacy-1', profile: 'user-1')],
    });
    await model.reloadGroups();

    expect(model.state.map((g) => g.name), contains('Legacy Group'));
  });
}
