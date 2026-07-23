import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/substack/substack_models.dart';
import 'package:quax/plugins/substack/substack_reader_screen.dart';
import 'package:quax/plugins/substack/substack_store.dart';
import 'package:quax/ui/dates.dart';
import 'package:quax/ui/errors.dart';

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
        appBar: AppBar(title: Text(widget.publication.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.publication.name)),
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
                return SubstackPostTile(post: snapshot.posts[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class SubstackPostTile extends StatelessWidget {
  final SubstackPost post;

  const SubstackPostTile({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final readStore = context.read<SubstackReadStore>();
    return ScopedBuilder<SubstackReadStore, Set<String>>(
      store: readStore,
      onState: (context, readIds) {
        final unread = !readIds.contains(post.id);
        final theme = Theme.of(context);
        final date = post.publishedAt;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: post.coverImage == null
              ? CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.article_outlined, color: theme.colorScheme.onSurfaceVariant),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ExtendedImage.network(post.coverImage!, width: 56, height: 56, fit: BoxFit.cover),
                ),
          title: Text(
            post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w400),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                [
                  post.publicationName,
                  if (date != null) createRelativeDate(date),
                  if (post.isPaywalled) L10n.of(context).plugin_substack_paywalled,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              if (post.excerpt != null) ...[
                const SizedBox(height: 4),
                Text(post.excerpt!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
          isThreeLine: post.excerpt != null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SubstackReaderScreen(post: post)),
            );
          },
        );
      },
    );
  }
}
