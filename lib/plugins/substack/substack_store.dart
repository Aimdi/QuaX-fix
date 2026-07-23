import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/plugins/substack/substack_client.dart';
import 'package:quax/plugins/substack/substack_models.dart';

class SubstackPublicationsStore extends Store<List<SubstackPublication>> {
  final BasePrefService prefs;

  SubstackPublicationsStore(this.prefs) : super(const []);

  Future<void> load() async {
    await execute(() async {
      return SubstackPublication.listFromPrefs(prefs.get(optionPluginSubstackPublications));
    });
  }

  Future<void> add(SubstackPublication publication) async {
    await execute(() async {
      final next = [...state.where((e) => e.id != publication.id), publication];
      await prefs.set(optionPluginSubstackPublications, SubstackPublication.listToPrefs(next));
      return next;
    });
  }

  Future<void> remove(String id) async {
    await execute(() async {
      final next = state.where((e) => e.id != id).toList();
      await prefs.set(optionPluginSubstackPublications, SubstackPublication.listToPrefs(next));
      return next;
    });
  }
}

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
