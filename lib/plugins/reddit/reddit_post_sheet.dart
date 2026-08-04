import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_listing_screen.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';
import 'package:xta/utils/urls.dart';

/// Everywhere a post can take you, without leaving the feed to find out.
///
/// The author and the subreddit are the two things a reader wants next and
/// neither had anywhere to go before: tapping a post only ever opened its
/// comments. The rest are the actions that were already possible but buried
/// inside the thread screen.
Future<void> openRedditPostSheet(BuildContext context, RedditPost post) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(child: _RedditPostSheet(post: post)),
  );
}

/// The public URL of a post, which is what gets shared and opened outside.
String redditPostUrl(RedditPost post) => 'https://www.reddit.com${post.permalink}';

class _RedditPostSheet extends StatelessWidget {
  final RedditPost post;

  const _RedditPostSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final author = post.author;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Text(
            post.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (author != null)
          _RedditSheetAction(
            icon: Icons.person_outline,
            label: 'u/$author',
            onTap: () => _push(context, RedditListingScreen.user(author)),
          ),
        _RedditSheetAction(
          icon: Icons.travel_explore,
          label: 'r/${post.subreddit}',
          onTap: () => _push(context, RedditListingScreen.subreddit(post.subreddit)),
        ),
        _RedditFollowAction(subreddit: post.subreddit),
        _RedditSheetAction(
          icon: Icons.open_in_new,
          label: l10n.open_in_browser,
          // Launch before dismissing: once the sheet is gone its context is
          // defunct, and openUri needs a live one.
          onTap: () async {
            await openUri(context, redditPostUrl(post));
            if (context.mounted) Navigator.pop(context);
          },
        ),
        _RedditSheetAction(
          icon: Icons.link,
          label: l10n.share_link,
          onTap: () {
            Navigator.pop(context);
            Share.share(redditPostUrl(post));
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// The navigator is taken before the sheet closes: afterwards this context is
  /// no longer in the tree and cannot be used to push anything.
  void _push(BuildContext context, Widget screen) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// Follow or unfollow, worded for whichever it currently is.
class _RedditFollowAction extends StatelessWidget {
  final String subreddit;

  const _RedditFollowAction({required this.subreddit});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return ScopedBuilder<RedditSubredditsStore, List<String>>(
      store: context.read<RedditSubredditsStore>(),
      onState: (context, names) {
        final followed = isFollowedSubreddit(names, subreddit);

        return _RedditSheetAction(
          icon: followed ? Icons.favorite : Icons.favorite_border,
          label: followed ? l10n.unsubscribe : l10n.subscribe,
          onTap: () async {
            final navigator = Navigator.of(context);
            await toggleRedditFollow(context, subreddit, followed: followed);
            navigator.pop();
          },
        );
      },
    );
  }
}

/// One pill, the shape Stealth uses: outlined, full width, icon then label.
class _RedditSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RedditSheetAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: theme.colorScheme.primary),
          foregroundColor: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
