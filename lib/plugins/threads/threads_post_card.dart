import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/threads/threads_models.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tweetFlatCard(
          color: theme.cardColor,
          child: InkWell(
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  if (post.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(post.text, style: theme.textTheme.bodyMedium),
                  ],
                  if (post.hasMedia) ...[
                    const SizedBox(height: 10),
                    _media(context),
                  ],
                ],
              ),
            ),
          ),
        ),
        tweetHairlineDivider(context),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = post.avatarUrl;
    final date = post.publishedAt;

    return Row(
      children: [
        ClipOval(
          child: avatar == null
              ? FallbackAvatar(
                  seed: post.handle,
                  displayName: post.authorName,
                  size: 32,
                  accent: theme.colorScheme.primary)
              : ExtendedImage.network(avatar,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  cacheWidth: (32 * MediaQuery.devicePixelRatioOf(context)).ceil()),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(post.authorName,
              overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text('@${post.handle}',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        if (showSourceBadge) ...[
          const SizedBox(width: 6),
          _badge(context, L10n.of(context).plugin_threads_title),
        ],
        const Spacer(),
        if (date != null) Text(createCompactDate(date), style: theme.textTheme.bodySmall),
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
        child: ExtendedImage.network(post.images.first,
            fit: BoxFit.cover, cacheWidth: (width * scale).ceil()),
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
          child: ExtendedImage.network(post.images[index],
              width: 200, height: 220, fit: BoxFit.cover, cacheWidth: (200 * scale).ceil()),
        ),
      ),
    );
  }
}
