import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_actions.dart';
import 'package:xta/plugins/reddit/reddit_feed_list.dart';
import 'package:xta/plugins/reddit/reddit_sort_sheet.dart';

// The failure wording moved to reddit_states.dart, next to the widget that
// renders it. Re-exported so the several files that ask this screen for it
// keep working.
export 'package:xta/plugins/reddit/reddit_states.dart' show redditErrorMessage;

/// Account-free Reddit reading: the subreddits you follow, newest first.
class RedditScreen extends StatelessWidget {
  final ScrollController scrollController;

  const RedditScreen({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const RedditFeedTitle(), actions: const [RedditFeedActions()]),
      body: RedditFeedList(scrollController: scrollController),
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
    final sort = redditSortLabel(context, storedRedditSort(PrefService.of(context)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(L10n.of(context).plugin_reddit_title, overflow: TextOverflow.ellipsis),
        Text(
          sort.label,
          style: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
