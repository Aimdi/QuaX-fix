import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
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
      body: ScopedBuilder<SubstackArchiveStore, SubstackFeedSnapshot>(
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
