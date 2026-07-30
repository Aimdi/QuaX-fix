import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/ui/x_controls.dart';
import 'package:xta/plugins/substack/substack_client.dart';
import 'package:xta/plugins/substack/substack_models.dart';
import 'package:xta/plugins/substack/substack_post_card.dart';
import 'package:xta/plugins/substack/substack_store.dart';
import 'package:xta/subscriptions/users_model.dart';
import 'package:xta/ui/errors.dart';

class SubstackArchiveScreen extends StatefulWidget {
  final SubstackPublication publication;

  const SubstackArchiveScreen({super.key, required this.publication});

  @override
  State<SubstackArchiveScreen> createState() => _SubstackArchiveScreenState();
}

class _SubstackArchiveScreenState extends State<SubstackArchiveScreen> {
  SubstackArchiveStore? _store;
  final _searchController = TextEditingController();
  var _query = '';
  List<SubstackPost>? _results;
  Object? _searchError;
  var _searching = false;

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    setState(() {
      _query = trimmed;
      _searchError = null;
      _results = null;
      _searching = trimmed.isNotEmpty;
    });
    if (trimmed.isEmpty) {
      return;
    }
    try {
      final results = await context.read<SubstackClient>().searchPosts(widget.publication, trimmed);
      if (mounted && _query == trimmed) setState(() => _results = results);
    } catch (e) {
      if (mounted && _query == trimmed) setState(() => _searchError = e);
    } finally {
      if (mounted && _query == trimmed) setState(() => _searching = false);
    }
  }

  /// The search pane replaces the archive while a query stands; clearing the
  /// field is the way back, so the archive keeps its scroll position.
  Widget _searchResults(BuildContext context) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return FullPageErrorWidget(
        error: _searchError,
        stackTrace: null,
        prefix: L10n.of(context).plugin_substack_load_error,
        onRetry: () => _search(_query),
      );
    }
    final results = _results ?? const <SubstackPost>[];
    if (results.isEmpty) {
      return Center(child: Text(L10n.of(context).plugin_substack_feed_empty));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => SubstackPostCard(post: results[index], showSourceBadge: false),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = SubstackArchiveStore(context.read(), widget.publication);
      setState(() => _store = store);
      store.refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _store?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.publication.name),
          actions: [SubstackFollowButton(publication: widget.publication)],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.publication.name),
        actions: [SubstackFollowButton(publication: widget.publication)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: XSearchField(
              controller: _searchController,
              hintText: L10n.of(context).search,
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _query.isNotEmpty
                ? _searchResults(context)
                : ScopedBuilder<SubstackArchiveStore, SubstackFeedSnapshot>(
        store: store,
        onError: (_, error) => FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: L10n.of(context).plugin_substack_load_error,
          onRetry: store.refresh,
        ),
        onLoading: (_) => const Center(child: CircularProgressIndicator()),
        onState: (context, snapshot) {
          if (snapshot.posts.isEmpty) {
            return Center(child: Text(L10n.of(context).plugin_substack_feed_empty));
          }
          return RefreshIndicator(
            onRefresh: store.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: snapshot.posts.length + (snapshot.canLoadMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= snapshot.posts.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: store.loadMore,
                        child: Text(L10n.of(context).plugin_substack_load_more),
                      ),
                    ),
                  );
                }
                return SubstackPostCard(post: snapshot.posts[index], showSourceBadge: false);
              },
            ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }
}

/// Follows or unfollows the publication, reflecting whichever it currently is.
///
/// Observes the store rather than reading it once, so arriving here from an
/// article shows the right label without a reload.
class SubstackFollowButton extends StatelessWidget {
  final SubstackPublication publication;

  const SubstackFollowButton({super.key, required this.publication});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final store = context.read<SubstackPublicationsStore>();

    return ScopedBuilder<SubstackPublicationsStore, List<SubstackPublication>>(
      store: store,
      onState: (context, followed) {
        final isFollowed = followed.any((e) => e.id == publication.id);

        return TextButton.icon(
          icon: Icon(isFollowed ? Icons.check : Icons.add, size: 18),
          label: Text(isFollowed ? l10n.unsubscribe : l10n.subscribe),
          onPressed: () async {
            final subscriptions = context.read<SubscriptionsModel>();
            isFollowed ? await store.remove(publication.id) : await store.add(publication);
            // A publication is a group member too; the editor reads that list.
            await subscriptions.reloadSubscriptions();
          },
        );
      },
    );
  }
}
