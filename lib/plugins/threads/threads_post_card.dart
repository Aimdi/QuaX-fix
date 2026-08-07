import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/threads/threads_models.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';
import 'package:xta/tweet/tweet.dart' show tweetCardColor;
import 'package:xta/tweet/tweet_chrome.dart';
import 'package:xta/ui/dates.dart';
import 'package:xta/utils/urls.dart';

/// A Threads post as a timeline card.
///
/// Shaped like the posts around it, because it sits among them. There is no
/// footer of counts: a feed carries no likes or replies, and a row of zeroes
/// would be an invention.
class ThreadsPostCard extends StatelessWidget {
  final ThreadsPost post;

  /// Set in a mixed timeline so the card says where it came from.
  final bool showSourceBadge;

  const ThreadsPostCard({super.key, required this.post, this.showSourceBadge = true});

  void _open(BuildContext context) {
    final url = post.url;
    if (url != null) {
      openUri(context, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The same shape a tweet has: avatar down the left, everything else in a
    // column beside it, so a Threads post sitting in a mixed timeline reads as
    // one of the row rather than a differently-built card.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tweetFlatCard(
          color: tweetCardColor(context),
          child: InkWell(
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(context, 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(context),
                        if (post.text.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(post.text, style: theme.textTheme.bodyMedium),
                        ],
                        if (post.hasMedia) ...[const SizedBox(height: 10), _media(context)],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        tweetHairlineDivider(context),
      ],
    );
  }

  Widget _avatar(BuildContext context, double size) {
    final theme = Theme.of(context);
    final avatar = post.avatarUrl;

    return ClipOval(
      child: avatar == null
          ? FallbackAvatar(
              seed: post.handle,
              displayName: post.authorName,
              size: size,
              accent: theme.colorScheme.primary,
            )
          : ExtendedImage.network(
              avatar,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
            ),
    );
  }

  /// Name, then handle and time on a quieter line beneath it — the two-line
  /// author block a tweet uses, rather than name and handle crowded onto one.
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final date = post.publishedAt;
    final metaStyle = theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                post.authorName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (showSourceBadge) ...[const SizedBox(width: 6), _badge(context, L10n.of(context).plugin_threads_title)],
          ],
        ),
        Row(
          children: [
            Flexible(
              child: Text('@${post.handle}', overflow: TextOverflow.ellipsis, style: metaStyle),
            ),
            if (date != null) ...[Text(' · ', style: metaStyle), Text(createCompactDate(date), style: metaStyle)],
          ],
        ),
      ],
    );
  }

  Widget _badge(BuildContext context, String label) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }

  /// One picture fills the width; several sit in a row that scrolls, so a
  /// carousel of eight does not push the next post off the bottom of the world.
  Widget _media(BuildContext context) {
    final radius = tweetMediaRadiusOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final scale = MediaQuery.devicePixelRatioOf(context);

    if (post.images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ExtendedImage.network(post.images.first, fit: BoxFit.cover, cacheWidth: (width * scale).ceil()),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: post.images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: ExtendedImage.network(
            post.images[index],
            width: 200,
            height: 220,
            fit: BoxFit.cover,
            cacheWidth: (200 * scale).ceil(),
          ),
        ),
      ),
    );
  }
}
