/// One row of a thread.
///
/// Pulled out of the screen so the screen is a list and this is a comment: the
/// two had grown into one 100-line builder, which is where the layout problems
/// hid — a header `Row` that burst at twice the text size, a fold with nothing
/// on screen saying it could be folded, and a removed comment rendered as if
/// somebody had written the word "[removed]".
library;

import 'package:flutter/material.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_avatar.dart';
import 'package:xta/plugins/reddit/reddit_comments.dart';
import 'package:xta/plugins/reddit/reddit_listing_screen.dart';
import 'package:xta/plugins/reddit/reddit_post_media.dart';
import 'package:xta/ui/dates.dart';

/// How far each level of replies is indented, and how deep that goes.
///
/// Reddit threads nest without limit; a phone cannot. Past this depth replies
/// keep their thread line but stop moving right, so a deep argument stays
/// readable instead of collapsing into a column one word wide.
const double kRedditIndentPerLevel = 10;
const int kRedditMaxIndentDepth = 8;

/// The thread lines, one colour per level.
///
/// Indentation alone stops telling you anything once it is capped: two replies
/// at depth 9 and depth 12 sit at the same x. The rail colour keeps saying
/// which level you are on, and repeats slowly enough that neighbours differ.
const redditRailColors = <Color>[
  Color(0xFF1D9BF0),
  Color(0xFF00BA7C),
  Color(0xFFFFB300),
  Color(0xFFE84462),
  Color(0xFF7856FF),
  Color(0xFF00838F),
];

Color redditRailColor(int depth) => redditRailColors[(depth - 1) % redditRailColors.length];

double redditIndentFor(int depth) =>
    kRedditIndentPerLevel * (depth > kRedditMaxIndentDepth ? kRedditMaxIndentDepth : depth);

/// A comment, foldable, with everything a reader judges it by: who, when, how
/// well it went down, and whether it is the person who posted.
class RedditCommentTile extends StatelessWidget {
  final RedditComment comment;
  final int depth;

  /// How many replies the fold is holding, when [folded].
  final int hidden;
  final bool folded;
  final VoidCallback onToggle;

  const RedditCommentTile({
    super.key,
    required this.comment,
    required this.depth,
    required this.folded,
    required this.onToggle,
    this.hidden = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return Semantics(
      // Names the action without swallowing the comment itself, so a screen
      // reader still reads out who said what and then how to fold it.
      onTapHint: folded ? l10n.clickToShowMore : l10n.hide,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 + redditIndentFor(depth), 6, 12, 6),
          child: Container(
            padding: EdgeInsets.only(left: depth == 0 ? 0 : 8),
            decoration: depth == 0
                ? null
                : BoxDecoration(
                    border: Border(left: BorderSide(color: redditRailColor(depth), width: 2)),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RedditCommentHeader(comment: comment, folded: folded, hidden: hidden),
                const SizedBox(height: 4),
                if (!folded) _body(context, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ThemeData theme) {
    // Reddit keeps the row and takes the words. Saying so quietly beats
    // printing "[removed]" in the same type as everything somebody wrote.
    if (comment.isRemoved) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              comment.body,
              style: theme.textTheme.bodyMedium!.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.body.isNotEmpty) Text(comment.body, style: theme.textTheme.bodyMedium),
        RedditCommentImages(urls: comment.mediaUrls),
      ],
    );
  }
}

/// Who, when, and how the fold stands.
///
/// A `Wrap` rather than a `Row`: at twice the text size the name, the score and
/// the age no longer fit on one line, and a `Row` answered that by overflowing
/// off the side of the screen.
class _RedditCommentHeader extends StatelessWidget {
  final RedditComment comment;
  final bool folded;
  final int hidden;

  const _RedditCommentHeader({required this.comment, required this.folded, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTextStyle.merge(
      style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 2,
        children: [
          Icon(folded ? Icons.chevron_right : Icons.expand_more, size: 16, color: theme.colorScheme.outline),
          _author(context, theme),
          if (comment.score != null) _score(theme),
          if (comment.createdAt != null) Text(createRelativeDate(comment.createdAt!)),
          if (folded) _foldCount(theme),
        ],
      ),
    );
  }

  Widget _author(BuildContext context, ThemeData theme) {
    final submitter = comment.isSubmitter;
    final name = comment.hasAuthor ? 'u/${comment.author}' : comment.author ?? '';

    final label = ConstrainedBox(
      // A `Wrap` hands its children unbounded width, so a long username would
      // run off the side rather than being cut short.
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RedditAvatar(name: comment.author, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: submitter ? theme.colorScheme.onPrimaryContainer : null,
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      // A name in a thread is a way to the rest of what they posted, the same
      // as it is on the card. A deleted account is not a way anywhere.
      onTap: comment.hasAuthor
          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => RedditListingScreen.user(comment.author!)))
          : null,
      child: submitter
          // The person who posted is marked by shape as well as colour: a tint
          // alone is invisible to a reader who cannot see the tint.
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: label,
            )
          : label,
    );
  }

  Widget _score(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.arrow_upward, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Text('${comment.score}'),
      ],
    );
  }

  Widget _foldCount(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('+${hidden + 1}', style: theme.textTheme.labelSmall),
    );
  }
}

/// Replies Reddit held back. The row says how many and opens the subtree's own
/// page, rather than the thread ending mid-air with no sign anything is
/// missing — which is what silently dropping these rows did.
class RedditMoreRepliesTile extends StatelessWidget {
  final RedditComment comment;
  final int depth;
  final VoidCallback? onOpen;

  const RedditMoreRepliesTile({super.key, required this.comment, required this.depth, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final count = (comment.moreCount ?? -1) > 0 ? ' · ${comment.moreCount}' : '';

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12 + redditIndentFor(depth), 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.subdirectory_arrow_right, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${l10n.plugin_reddit_more_replies}$count',
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
