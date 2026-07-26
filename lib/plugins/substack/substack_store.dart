import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quax/plugins/substack/substack_client.dart';
import 'package:quax/plugins/substack/substack_models.dart';

/// The publications the reader follows, kept in the database.
///
/// They used to live in a preferences blob, which is why they could never join
/// a subscription group. Anything still in that blob is imported on first load
/// and the blob cleared, so nobody has to re-add what they already followed.
class SubstackPublicationsStore extends Store<List<SubstackPublication>> {
  final BasePrefService prefs;

  SubstackPublicationsStore(this.prefs) : super(const []);

  Future<void> load() async {
    await execute(() async {
      await _importFromPrefs();
      return _read();
    });
  }

  Future<List<SubstackPublication>> _read() async {
    final database = await Repository.readOnly();
    final rows = await database.query(tableSubstackSubscription, orderBy: 'name COLLATE NOCASE');

    return rows.map(SubstackSubscription.fromMap).map(publicationOf).toList(growable: false);
  }

  Future<void> _importFromPrefs() async {
    final raw = prefs.get<String>(optionPluginSubstackPublications) ?? '';
    if (raw.isEmpty) {
      return;
    }

    for (final publication in SubstackPublication.listFromPrefs(raw)) {
      await _write(publication);
    }
    await prefs.set(optionPluginSubstackPublications, '');
  }

  Future<void> _write(SubstackPublication publication) async {
    final database = await Repository.writable();
    await database.insert(
      tableSubstackSubscription,
      subscriptionOf(publication).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> add(SubstackPublication publication) async {
    await execute(() async {
      await _write(publication);
      return _read();
    });
  }

  Future<void> remove(String id) async {
    await execute(() async {
      final database = await Repository.writable();
      await database.delete(tableSubstackSubscription, where: 'id = ?', whereArgs: [id]);
      // A publication that is gone should not linger as a member of a group.
      await database.delete(tableSubscriptionGroupMember, where: 'profile_id = ?', whereArgs: [id]);
      return _read();
    });
  }
}

/// The database row for a publication, and back again.
///
/// The plugin thinks in publications and the subscription tables think in
/// subscriptions; these keep the two from having to know each other's shape.
SubstackSubscription subscriptionOf(SubstackPublication publication) => SubstackSubscription(
      id: publication.id,
      baseUrl: publication.baseUrl,
      name: publication.name,
      logoUrl: publication.logoUrl,
      createdAt: DateTime.now(),
      inFeed: true,
    );

SubstackPublication publicationOf(SubstackSubscription subscription) => SubstackPublication(
      subdomain: subscription.id,
      baseUrl: subscription.baseUrl,
      name: subscription.name,
      logoUrl: subscription.logoUrl,
    );

class SubstackReadStore extends Store<Set<String>> {
  final BasePrefService prefs;

  SubstackReadStore(this.prefs) : super(const {});

  Future<void> load() async {
    await execute(() async {
      return readIdsFromPrefs(prefs.get(optionPluginSubstackReadIds)).toSet();
    });
  }

  Future<void> markRead(String id) async {
    if (id.isEmpty || state.contains(id)) return;
    await execute(() async {
      final next = [id, ...state];
      final capped = next.take(substackReadIdsCap).toList();
      await prefs.set(optionPluginSubstackReadIds, readIdsToPrefs(capped));
      return capped.toSet();
    });
  }

  bool isRead(String id) => state.contains(id);
}

class SubstackFeedStore extends Store<SubstackFeedSnapshot> {
  final SubstackClient client;
  final SubstackPublicationsStore publications;

  var _offset = 0;

  SubstackFeedStore(this.client, this.publications) : super(const SubstackFeedSnapshot());

  Future<void> refresh() async {
    _offset = 0;
    await execute(() => _fetchPage(replace: true));
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    await execute(() => _fetchPage(replace: false));
  }

  Future<SubstackFeedSnapshot> _fetchPage({required bool replace}) async {
    final pubs = publications.state;
    if (pubs.isEmpty) {
      return const SubstackFeedSnapshot();
    }

    final results = await Future.wait(pubs.map((p) async {
      try {
        final posts = await client.fetchPosts(p, limit: substackFeedPageSize, offset: _offset);
        return (posts: posts, failed: false);
      } catch (_) {
        return (posts: const <SubstackPost>[], failed: true);
      }
    }));

    final pagePosts = results.expand((e) => e.posts).toList();
    final failedCount = results.where((e) => e.failed).length;
    final canLoadMore = results.any((e) => e.posts.length >= substackFeedPageSize);

    _offset += substackFeedPageSize;

    final merged = replace ? pagePosts : _mergePosts(state.posts, pagePosts);
    merged.sort((a, b) => (b.postDate ?? '').compareTo(a.postDate ?? ''));

    return SubstackFeedSnapshot(
      posts: merged,
      canLoadMore: canLoadMore,
      failedCount: replace ? failedCount : state.failedCount,
    );
  }

  List<SubstackPost> _mergePosts(List<SubstackPost> existing, List<SubstackPost> incoming) {
    final seen = existing.map((e) => e.id).toSet();
    return [...existing, ...incoming.where((e) => !seen.contains(e.id))];
  }
}

class SubstackArchiveStore extends Store<SubstackFeedSnapshot> {
  final SubstackClient client;
  final SubstackPublication publication;

  var _offset = 0;

  SubstackArchiveStore(this.client, this.publication) : super(const SubstackFeedSnapshot());

  Future<void> refresh() async {
    _offset = 0;
    await execute(() => _fetchPage(replace: true));
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    await execute(() => _fetchPage(replace: false));
  }

  Future<SubstackFeedSnapshot> _fetchPage({required bool replace}) async {
    final page = await client.fetchPosts(publication, limit: substackFeedPageSize, offset: _offset);
    _offset += substackFeedPageSize;
    final posts = replace
        ? page
        : [...state.posts, ...page.where((e) => !state.posts.any((p) => p.id == e.id))];
    return SubstackFeedSnapshot(
      posts: posts,
      canLoadMore: page.length >= substackFeedPageSize,
      failedCount: 0,
    );
  }
}

class SubstackAddPublicationStore extends Store<SubstackPublication?> {
  final SubstackClient client;

  SubstackAddPublicationStore(this.client) : super(null);

  Future<SubstackPublication> lookup(String input) async {
    final base = resolveSubstackBase(input);
    if (base == null) {
      final error = SubstackClientException('Invalid Substack URL or handle');
      setError(error);
      throw error;
    }
    await execute(() => client.fetchPublication(base));
    final result = state;
    if (result == null) {
      throw SubstackClientException('Publication not found');
    }
    return result;
  }
}
