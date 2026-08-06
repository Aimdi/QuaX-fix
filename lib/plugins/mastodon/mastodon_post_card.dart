import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/mastodon/mastodon_models.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';
import 'package:xta/tweet/tweet_chrome.dart';
import 'package:xta/ui/dates.dart';
import 'package:xta/utils/urls.dart';

/// A Mastodon status as a timeline card.
class MastodonPostCard extends StatelessWidget {
  final MastodonPost post;
  final bool showSourceBadge;

  const MastodonPostCard({super.key, required this.post, this.showSourceBadge = true});

  void _open(BuildContext context) => openUri(context, post.url);

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
                  if (post.hasMedia) ...[const SizedBox(height: 10), _media(context)],
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
    final l10n = L10n.of(context);
    final avatar = post.avatarUrl;
    final date = post.publishedAt;

    return Row(
      children: [
        ClipOval(
          child: avatar == null
              ? FallbackAvatar(
                  seed: post.acct,
                  displayName: post.authorName,
                  size: 32,
                  accent: theme.colorScheme.primary,
                )
              : ExtendedImage.network(
                  avatar,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  cacheWidth: (32 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            post.authorName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '@${post.acct}',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        if (post.boosted) ...[
          const SizedBox(width: 6),
          Icon(Icons.repeat, size: 14, color: theme.colorScheme.onSurfaceVariant),
        ],
        if (showSourceBadge) ...[const SizedBox(width: 6), _badge(context, l10n.plugin_mastodon_title)],
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
