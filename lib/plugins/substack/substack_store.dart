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

class SubstackFeedStore extends Store<List<SubstackPost>> {
  final SubstackClient client;
  final SubstackPublicationsStore publications;

  SubstackFeedStore(this.client, this.publications) : super(const []);

  Future<void> refresh() async {
    await execute(() async {
      final pubs = publications.state;
      if (pubs.isEmpty) return const <SubstackPost>[];

      final batches = await Future.wait(pubs.map((p) => client.fetchPosts(p, limit: 8)));
      final merged = batches.expand((e) => e).toList()
        ..sort((a, b) => (b.postDate ?? '').compareTo(a.postDate ?? ''));
      return merged;
    });
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
