import 'package:flutter_triple/flutter_triple.dart';
import 'package:xta/database/repository.dart';

/// Likes that live on this device, in the same spirit as the X likes:
/// nothing is sent to Threads/Meta, no account is involved — the heart simply
/// remembers what the reader liked.
class ThreadsLikesStore extends Store<Set<String>> {
  ThreadsLikesStore() : super(const {});

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final database = await Repository.readOnly();
    final rows = await database.query(tableThreadsLocalLike, columns: ['id']);
    update({for (final row in rows) row['id'] as String});
  }

  bool isLiked(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    final database = await Repository.writable();
    if (state.contains(id)) {
      await database.delete(tableThreadsLocalLike, where: 'id = ?', whereArgs: [id]);
      update({...state}..remove(id));
    } else {
      await database.insert(tableThreadsLocalLike, {'id': id});
      update({...state, id});
    }
  }
}
