import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';
import 'package:quax/plugins/reddit/reddit_thread_screen.dart';
import 'package:quax/tweet/tweet_chrome.dart';
import 'package:quax/ui/dates.dart';

/// A Reddit post, compact.
///
/// One line of context, the title, and a small thumbnail beside it — the shape
/// Stealth uses, and about half the height of the ListTile this replaces. The
/// body is deliberately not shown: a self post's text belongs on the thread
/// screen, not in a feed you are scrolling past.
class RedditPostCard extends StatelessWidget {
  final RedditPost post;

  /// Set in a mixed timeline so the card says where it came from.
  final bool showSourceBadge;

  const RedditPostCard({super.key, required this.post, this.showSourceBadge = true});

  void _open(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RedditThreadScreen(post: post)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = post.thumbnailUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _context(context),
                      const SizedBox(height: 4),
                      Text(
                        post.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      _counts(context),
                    ],
                  ),
                ),
                if (thumbnail != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ExtendedImage.network(thumbnail, width: 64, height: 64, fit: BoxFit.cover),
                  ),
                ],
              ],
            ),
          ),
        ),
        tweetHairlineDivider(context),
      ],
    );
  }

  Widget _context(BuildContext context) {
    final theme = Theme.of(context);
    final date = post.createdAt;

    return DefaultTextStyle.merge(
      style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
      child: Row(
        children: [
          Flexible(
            child: Text('r/${post.subreddit}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
          ),
          if (showSourceBadge) ...[
            const SizedBox(width: 6),
            _badge(context, L10n.of(context).plugin_reddit_title),
          ],
          if (post.over18) ...[
            const SizedBox(width: 6),
            _badge(context, L10n.of(context).plugin_reddit_nsfw, tint: theme.colorScheme.error),
          ],
          const Spacer(),
          if (date != null) Text(createRelativeDate(date)),
        ],
      ),
    );
  }

  Widget _counts(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTextStyle.merge(
      style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
      child: Row(
        children: [
          Icon(Icons.arrow_upward, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text('${post.score}'),
          const SizedBox(width: 14),
          Icon(Icons.mode_comment_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text('${post.commentCount}'),
          if (post.author != null) ...[
            const SizedBox(width: 14),
            Flexible(child: Text('u/${post.author}', overflow: TextOverflow.ellipsis)),
          ],
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String label, {Color? tint}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: tint ?? theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: theme.textTheme.labelSmall!.copyWith(color: tint)),
    );
  }
}
