import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_actions.dart';
import 'package:xta/plugins/reddit/reddit_feed_list.dart';
import 'package:xta/plugins/reddit/reddit_listing_body.dart';
import 'package:xta/plugins/reddit/reddit_saved_screen.dart';
import 'package:xta/plugins/reddit/reddit_sort_sheet.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';

// The failure wording moved to reddit_states.dart, next to the widget that
// renders it. Re-exported so the several files that ask this screen for it
// keep working.
export 'package:xta/plugins/reddit/reddit_states.dart' show redditErrorMessage;

/// Account-free Reddit reading: the subreddits you follow, newest first.
class RedditScreen extends StatefulWidget {
  final ScrollController scrollController;

  const RedditScreen({super.key, required this.scrollController});

  @override
  State<RedditScreen> createState() => _RedditScreenState();
}

class _RedditScreenState extends State<RedditScreen> {
  final _popularKey = GlobalKey<RedditListingBodyState>();
  final _allKey = GlobalKey<RedditListingBodyState>();

  late RedditFeedMode _mode;
  bool _loadedStores = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mode = storedRedditFeedMode(PrefService.of(context, listen: false));
    if (!_loadedStores) {
      _loadedStores = true;
      unawaited(context.read<RedditSavedStore>().load());
    }
  }

  Future<void> _refreshCurrent() {
    return switch (_mode) {
      RedditFeedMode.following => context.read<RedditFeedStore>().refresh(
        force: true,
      ),
      RedditFeedMode.popular =>
        _popularKey.currentState?.refresh() ?? Future.value(),
      RedditFeedMode.all => _allKey.currentState?.refresh() ?? Future.value(),
    };
  }

  Future<void> _setMode(RedditFeedMode mode) async {
    await PrefService.of(
      context,
      listen: false,
    ).set(optionPluginRedditFeedMode, mode.name);
    if (mounted) {
      setState(() => _mode = mode);
    }
  }

  void _openSaved() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RedditSavedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const RedditFeedTitle(),
        actions: [
          IconButton(
            tooltip: L10n.of(context).saved,
            icon: const Icon(Icons.bookmark_border),
            onPressed: _openSaved,
          ),
          RedditFeedActions(onRefresh: _refreshCurrent),
        ],
      ),
      body: Column(
        children: [
          _ShellTabs(current: _mode, onSelected: _setMode),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() => switch (_mode) {
    RedditFeedMode.following => RedditFeedList(
      scrollController: widget.scrollController,
    ),
    RedditFeedMode.popular => RedditListingBody.subreddit(
      'popular',
      key: _popularKey,
      scrollController: widget.scrollController,
      showSourceBadge: false,
    ),
    RedditFeedMode.all => RedditListingBody.subreddit(
      'all',
      key: _allKey,
      scrollController: widget.scrollController,
      showSourceBadge: false,
    ),
  };
}

class _ShellTabs extends StatelessWidget {
  final RedditFeedMode current;
  final ValueChanged<RedditFeedMode> onSelected;

  const _ShellTabs({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            for (final mode in RedditFeedMode.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _ShellTab(
                    label: _feedModeLabel(context, mode),
                    selected: mode == current,
                    onTap: () => onSelected(mode),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _feedModeLabel(BuildContext context, RedditFeedMode mode) {
    final l10n = L10n.of(context);
    return switch (mode) {
      RedditFeedMode.following => l10n.plugin_reddit_feed_following,
      RedditFeedMode.popular => l10n.plugin_reddit_feed_popular,
      RedditFeedMode.all => l10n.plugin_reddit_feed_all,
    };
  }
}

class _ShellTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShellTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge!.copyWith(
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}

/// "Reddit", and underneath it the order the feed is actually in.
///
/// The sort is one stored choice that every listing obeys, and it was visible
/// only inside the sheet that sets it — so a reader who had once chosen Top had
/// nothing on screen telling them why their feed looked the way it did.
class RedditFeedTitle extends StatelessWidget {
  const RedditFeedTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = PrefService.of(context);
    final sort = redditSortTitle(
      context,
      storedRedditSort(prefs),
      storedRedditTimeFilter(prefs),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          L10n.of(context).plugin_reddit_title,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          sort,
          style: theme.textTheme.labelSmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
