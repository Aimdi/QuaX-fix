import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/plugins/bluesky/bluesky_models.dart';

/// Likes that live on this device — nothing is sent to Bluesky.
class BlueskyLikesStore extends Store<List<BlueskyPost>> {
  final BasePrefService prefs;

  BlueskyLikesStore(this.prefs) : super(const []);

  Set<String> _ids = const {};

  List<BlueskyPost> get likedPosts => state;

  Future<void> load() async {
    final database = await Repository.readOnly();
    final rows = await database.query(tableBlueskyLocalLike, columns: ['id']);
    _ids = {for (final row in rows) row['id'] as String};
    final posts = BlueskyPost.listFromPrefs(
      prefs.get<String>(optionPluginBlueskyLikedPosts),
    ).where((post) => _ids.contains(post.uri)).toList(growable: false);
    update(posts);
  }

  bool isLiked(String uri) => _ids.contains(uri);

  Future<void> toggle(BlueskyPost post) async {
    final id = post.uri;
    if (id.isEmpty) {
      return;
    }

    final database = await Repository.writable();
    if (_ids.contains(id)) {
      await database.delete(
        tableBlueskyLocalLike,
        where: 'id = ?',
        whereArgs: [id],
      );
      _ids = {..._ids}..remove(id);
      await _save(
        state.where((liked) => liked.uri != id).toList(growable: false),
      );
    } else {
      await database.insert(
        tableBlueskyLocalLike,
        {'id': id},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      _ids = {..._ids, id};
      await _save(
        [
          post,
          ...state.where((liked) => liked.uri != id),
        ].take(blueskyLikedPostsCap).toList(),
      );
    }
  }

  Future<void> _save(List<BlueskyPost> posts) async {
    await prefs.set(
      optionPluginBlueskyLikedPosts,
      BlueskyPost.listToPrefs(posts),
    );
    update(posts);
  }
}
