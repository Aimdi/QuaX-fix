import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/bluesky/bluesky_client.dart';
import 'package:xta/plugins/bluesky/bluesky_import_follows_screen.dart';
import 'package:xta/plugins/bluesky/bluesky_import_list_screen.dart';
import 'package:xta/plugins/bluesky/bluesky_likes_store.dart';
import 'package:xta/plugins/bluesky/bluesky_models.dart';
import 'package:xta/plugins/bluesky/bluesky_post_card.dart';
import 'package:xta/plugins/bluesky/bluesky_profile_screen.dart';
import 'package:xta/plugins/bluesky/bluesky_search_sheet.dart';
import 'package:xta/plugins/bluesky/bluesky_store.dart';
import 'package:xta/ui/errors.dart';

/// The Bluesky tab: local follows feed, plus a device-only Liked library.
class BlueskyScreen extends StatefulWidget {
  final ScrollController scrollController;

  const BlueskyScreen({super.key, required this.scrollController});

  @override
  State<BlueskyScreen> createState() => _BlueskyScreenState();
}

class _BlueskyScreenState extends State<BlueskyScreen> {
  final _shell = _BlueskyShellStore();
  final _likedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadHome();
      }
    });
  }

  @override
  void dispose() {
    _likedScrollController.dispose();
    _shell.destroy();
    super.dispose();
  }

  Future<void> _loadHome() async {
    final likes = context.read<BlueskyLikesStore>();
    final feed = context.read<BlueskyFeedStore>();
    await likes.load();
    await feed.refresh();
  }

  Future<void> _searchPeople() async {
    await showBlueskySearchSheet(context);
    if (mounted) {
      await context.read<BlueskyFeedStore>().refresh();
    }
  }

  Future<void> _addAccount() async {
    final actor = await showBlueskyAddAccountDialog(context);
    if (actor == null || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final client = context.read<BlueskyClient>();
    final accounts = context.read<BlueskyAccountsStore>();
    final l10n = L10n.of(context);

    try {
      final profile = await client.getProfile(actor);
      await accounts.add(profile.toAccount());
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(blueskyErrorMessage(l10n, e))));
      }
      return;
    }

    if (mounted) {
      await context.read<BlueskyFeedStore>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_bluesky_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.plugin_bluesky_search,
            onPressed: _searchPeople,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: l10n.plugin_bluesky_add,
            onPressed: _addAccount,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              final page = switch (value) {
                'following' => const BlueskyImportFollowsScreen(),
                'list' => const BlueskyImportListScreen(),
                _ => null,
              };
              if (page != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => page));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'following',
                child: Text(l10n.plugin_bluesky_import_following),
              ),
              PopupMenuItem(
                value: 'list',
                child: Text(l10n.plugin_bluesky_import_list),
              ),
            ],
          ),
        ],
      ),
      body: ScopedBuilder<_BlueskyShellStore, int>(
        store: _shell,
        onState: (context, tab) => Column(
          children: [
            _ShellTabs(selected: tab, onSelected: _shell.select),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  _HomePane(
                    scrollController: widget.scrollController,
                    onRefresh: _loadHome,
                  ),
                  _LikedPane(
                    scrollController: _likedScrollController,
                    likes: context.read<BlueskyLikesStore>(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlueskyShellStore extends Store<int> {
  _BlueskyShellStore() : super(0);

  void select(int index) => update(index);
}

class _ShellTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _ShellTabs({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          _ShellTab(
            label: l10n.plugin_bluesky_home,
            icon: Icons.home_outlined,
            selected: selected == 0,
            onTap: () => onSelected(0),
          ),
          _ShellTab(
            label: l10n.plugin_bluesky_liked,
            icon: Icons.favorite_border,
            selected: selected == 1,
            onTap: () => onSelected(1),
          ),
        ],
      ),
    );
  }
}

class _ShellTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ShellTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.labelMedium!.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePane extends StatelessWidget {
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  const _HomePane({required this.scrollController, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return ScopedBuilder<BlueskyFeedStore, List<BlueskyPost>>.transition(
      store: context.read<BlueskyFeedStore>(),
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onError: (context, error) => Padding(
        padding: const EdgeInsets.all(24),
        child: FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: blueskyErrorMessage(l10n, error ?? Exception()),
          onRetry: () => context.read<BlueskyFeedStore>().refresh(),
        ),
      ),
      onState: (context, posts) => _feed(context, l10n, posts),
    );
  }

  Widget _feed(BuildContext context, L10n l10n, List<BlueskyPost> posts) {
    if (posts.isEmpty) {
      return ScopedBuilder<BlueskyAccountsStore, List<BlueskyAccount>>(
        store: context.read<BlueskyAccountsStore>(),
        onState: (context, accounts) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              accounts.isEmpty ? l10n.plugin_bluesky_empty : l10n.plugin_bluesky_no_posts,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        itemCount: posts.length,
        itemBuilder: (context, index) =>
            BlueskyPostCard(key: ValueKey(posts[index].uri), post: posts[index], showSourceBadge: false),
      ),
    );
  }
}

class _LikedPane extends StatelessWidget {
  final ScrollController scrollController;
  final BlueskyLikesStore likes;

  const _LikedPane({required this.scrollController, required this.likes});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return RefreshIndicator(
      onRefresh: likes.load,
      child: ScopedBuilder<BlueskyLikesStore, List<BlueskyPost>>(
        store: likes,
        onState: (context, posts) {
          if (posts.isEmpty) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 52,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.plugin_bluesky_liked_empty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            );
          }

          return ListView.builder(
            controller: scrollController,
            itemCount: posts.length,
            itemBuilder: (context, index) => BlueskyPostCard(
              key: ValueKey('liked-${posts[index].uri}'),
              post: posts[index],
              showSourceBadge: false,
            ),
          );
        },
      ),
    );
  }
}

/// Asks for a handle or DID, and hands back the normalised one.
Future<String?> showBlueskyAddAccountDialog(BuildContext context, {bool lookup = false}) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final l10n = L10n.of(dialogContext);
      String? error;

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(lookup ? l10n.plugin_bluesky_lookup : l10n.plugin_bluesky_add),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.plugin_bluesky_handle_hint,
              errorText: error,
            ),
            onSubmitted: (_) {
              final handle = normaliseBlueskyHandle(controller.text);
              if (handle == null) {
                setState(() => error = l10n.plugin_bluesky_invalid_handle);
              } else {
                Navigator.pop(context, handle);
              }
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () {
                final handle = normaliseBlueskyHandle(controller.text);
                if (handle == null) {
                  setState(() => error = l10n.plugin_bluesky_invalid_handle);
                } else {
                  Navigator.pop(context, handle);
                }
              },
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    },
  );
}
