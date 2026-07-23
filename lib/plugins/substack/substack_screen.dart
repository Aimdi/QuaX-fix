import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/substack/substack_add_screen.dart';
import 'package:quax/plugins/substack/substack_models.dart';
import 'package:quax/plugins/substack/substack_reader_screen.dart';
import 'package:quax/plugins/substack/substack_store.dart';
import 'package:quax/ui/errors.dart';

class SubstackScreen extends StatefulWidget {
  final ScrollController scrollController;

  const SubstackScreen({super.key, required this.scrollController});

  @override
  State<SubstackScreen> createState() => _SubstackScreenState();
}

class _SubstackScreenState extends State<SubstackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pubs = context.read<SubstackPublicationsStore>();
      final feed = context.read<SubstackFeedStore>();
      await pubs.load();
      await feed.refresh();
    });
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SubstackAddScreen()),
    );
    if (added == true && mounted) {
      await context.read<SubstackFeedStore>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pubs = context.read<SubstackPublicationsStore>();
    final feed = context.read<SubstackFeedStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).plugin_substack_title),
        actions: [
          IconButton(
            tooltip: L10n.of(context).plugin_substack_add,
            icon: const Icon(Icons.add),
            onPressed: _openAdd,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await pubs.load();
          await feed.refresh();
        },
        child: ScopedBuilder<SubstackPublicationsStore, List<SubstackPublication>>(
          store: pubs,
          onError: (_, error) => FullPageErrorWidget(
            error: error,
            stackTrace: null,
            prefix: L10n.of(context).plugin_substack_load_error,
            onRetry: pubs.load,
          ),
          onLoading: (_) => const Center(child: CircularProgressIndicator()),
          onState: (context, publications) {
            if (publications.isEmpty) {
              return ListView(
                controller: widget.scrollController,
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.newspaper_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      L10n.of(context).plugin_substack_empty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      L10n.of(context).plugin_substack_empty_description,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: _openAdd,
                      icon: const Icon(Icons.add),
                      label: Text(L10n.of(context).plugin_substack_add),
                    ),
                  ),
                ],
              );
            }

            return ScopedBuilder<SubstackFeedStore, List<SubstackPost>>(
              store: feed,
              onError: (_, error) => FullPageErrorWidget(
                error: error,
                stackTrace: null,
                prefix: L10n.of(context).plugin_substack_load_error,
                onRetry: feed.refresh,
              ),
              onLoading: (_) => const Center(child: CircularProgressIndicator()),
              onState: (context, posts) {
                return ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: posts.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _FollowedStrip(
                        publications: publications,
                        onRemove: (id) async {
                          await pubs.remove(id);
                          await feed.refresh();
                        },
                      );
                    }
                    final post = posts[index - 1];
                    return _PostTile(post: post);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FollowedStrip extends StatelessWidget {
  final List<SubstackPublication> publications;
  final Future<void> Function(String id) onRemove;

  const _FollowedStrip({required this.publications, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: publications.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pub = publications[index];
          return InputChip(
            avatar: pub.logoUrl == null
                ? const Icon(Icons.newspaper, size: 18)
                : ClipOval(
                    child: ExtendedImage.network(pub.logoUrl!, width: 24, height: 24, fit: BoxFit.cover),
                  ),
            label: Text(pub.name),
            onDeleted: () => onRemove(pub.id),
            deleteIcon: const Icon(Icons.close, size: 16),
          );
        },
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final SubstackPost post;

  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: post.coverImage == null
          ? const CircleAvatar(child: Icon(Icons.article_outlined))
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ExtendedImage.network(post.coverImage!, width: 56, height: 56, fit: BoxFit.cover),
            ),
      title: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          post.publicationName,
          if (post.isPaywalled) L10n.of(context).plugin_substack_paywalled,
          if (post.subtitle != null && post.subtitle!.trim().isNotEmpty) post.subtitle!,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SubstackReaderScreen(post: post)),
        );
      },
    );
  }
}
