import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:intl/intl.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';
import 'package:quax/plugins/reddit/reddit_store.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/urls.dart';

String redditErrorMessage(L10n l10n, Object error) {
  if (error is RedditException) {
    return switch (error.kind) {
      RedditErrorKind.notConfigured => l10n.plugin_reddit_not_configured,
      RedditErrorKind.unauthorized => l10n.plugin_reddit_error_client_id,
      RedditErrorKind.blocked => l10n.plugin_reddit_error_blocked,
      RedditErrorKind.notFound => l10n.plugin_reddit_error_not_found,
      RedditErrorKind.rateLimited => l10n.plugin_reddit_error_rate_limited,
      RedditErrorKind.badResponse => l10n.plugin_reddit_error_response,
      RedditErrorKind.network => l10n.plugin_reddit_error_network,
    };
  }
  return '$error';
}

/// Account-free Reddit reading: the subreddits you follow, newest first.
class RedditScreen extends StatefulWidget {
  final ScrollController scrollController;

  const RedditScreen({super.key, required this.scrollController});

  @override
  State<RedditScreen> createState() => _RedditScreenState();
}

class _RedditScreenState extends State<RedditScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final subs = context.read<RedditSubredditsStore>();
      await subs.load();
      if (mounted) {
        await context.read<RedditFeedStore>().refresh();
      }
    });
  }

  Future<void> _editClientId() async {
    final prefs = PrefService.of(context, listen: false);
    final controller = TextEditingController(text: prefs.get<String>(optionPluginRedditClientId) ?? '');

    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = L10n.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.plugin_reddit_client_id),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.plugin_reddit_client_id_help, style: Theme.of(dialogContext).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                decoration: InputDecoration(hintText: l10n.plugin_reddit_client_id),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    if (saved == null || !mounted) return;
    await prefs.set(optionPluginRedditClientId, saved);
    context.read<RedditClient>().forgetToken();
    if (mounted) {
      await context.read<RedditFeedStore>().refresh();
    }
  }

  Future<void> _addSubreddit() async {
    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = L10n.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.plugin_reddit_add),
          content: TextField(
            controller: controller,
            autofocus: true,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'r/dartlang'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );

    if (entered == null || entered.isEmpty || !mounted) return;

    if (normaliseSubreddit(entered) == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L10n.of(context).plugin_reddit_error_not_found)));
      return;
    }

    await context.read<RedditSubredditsStore>().add(entered);
    if (mounted) {
      await context.read<RedditFeedStore>().refresh();
    }
  }

  Future<void> _manageSubreddits() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final store = sheetContext.read<RedditSubredditsStore>();
        return SafeArea(
          child: ScopedBuilder<RedditSubredditsStore, List<String>>(
            store: store,
            onState: (_, names) => ListView(
              shrinkWrap: true,
              children: [
                for (final name in names)
                  ListTile(
                    title: Text('r/$name'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await store.remove(name);
                        if (sheetContext.mounted) {
                          await sheetContext.read<RedditFeedStore>().refresh();
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final feed = context.read<RedditFeedStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_reddit_title),
        actions: [
          IconButton(
            tooltip: l10n.plugin_reddit_add,
            icon: const Icon(Icons.add),
            onPressed: _addSubreddit,
          ),
          IconButton(
            tooltip: l10n.subscriptions,
            icon: const Icon(Icons.list),
            onPressed: _manageSubreddits,
          ),
          IconButton(
            tooltip: l10n.plugin_reddit_client_id,
            icon: const Icon(Icons.key),
            onPressed: _editClientId,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: feed.refresh,
        child: ScopedBuilder<RedditFeedStore, List<RedditPost>>.transition(
          store: feed,
          onError: (_, error) => FullPageErrorWidget(
            error: error,
            stackTrace: null,
            prefix: redditErrorMessage(l10n, error!),
            onRetry: feed.refresh,
          ),
          onLoading: (_) => const Center(child: CircularProgressIndicator()),
          onState: (_, posts) {
            if (posts.isEmpty) {
              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                children: [
                  Icon(Icons.forum_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(l10n.plugin_reddit_empty, textAlign: TextAlign.center),
                ],
              );
            }

            return ListView.separated(
              controller: widget.scrollController,
              itemCount: posts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _RedditPostTile(post: posts[index]),
            );
          },
        ),
      ),
    );
  }
}

class _RedditPostTile extends StatelessWidget {
  final RedditPost post;

  const _RedditPostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numbers = NumberFormat.compact();
    final created = post.createdAt;
    final meta = [
      'r/${post.subreddit}',
      '${numbers.format(post.score)} · ${numbers.format(post.commentCount)}',
      if (created != null) DateFormat.yMMMd().add_Hm().format(created),
    ].join('  ·  ');

    return ListTile(
      leading: post.thumbnailUrl == null
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(post.thumbnailUrl!, width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56)),
            ),
      title: Text(post.title, maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(meta, style: theme.textTheme.bodySmall),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RedditPostScreen(post: post)),
      ),
    );
  }
}

/// A post's own text, plus a way out to the discussion or the linked article.
/// Comments are not implemented yet.
class RedditPostScreen extends StatelessWidget {
  final RedditPost post;

  const RedditPostScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final url = post.url;
    final selfText = post.selfText;

    return Scaffold(
      appBar: AppBar(title: Text('r/${post.subreddit}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(post.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            [if (post.author != null) 'u/${post.author}', '${post.score}'].join('  ·  '),
            style: theme.textTheme.bodySmall,
          ),
          if (selfText != null && selfText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(selfText, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          if (url != null && !post.isSelf)
            FilledButton.icon(
              onPressed: () => openUri(context, url),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.open_in_browser),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => openUri(context, 'https://www.reddit.com${post.permalink}'),
            icon: const Icon(Icons.forum_outlined),
            label: Text(l10n.plugin_reddit_open_discussion),
          ),
        ],
      ),
    );
  }
}
