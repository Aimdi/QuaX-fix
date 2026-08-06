import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';
import 'package:xta/plugins/pixiv/pixiv_user_screen.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';
import 'package:xta/tweet/tweet_chrome.dart';
import 'package:xta/ui/dates.dart';
import 'package:xta/utils/urls.dart';

/// One Pixiv illust as a timeline card. Opens the artwork on pixiv.net.
class PixivIllustCard extends StatelessWidget {
  final PixivIllust illust;

  const PixivIllustCard({super.key, required this.illust});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tweetFlatCard(
          color: theme.cardColor,
          child: InkWell(
            onTap: () => openUri(context, illust.url),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  if (illust.title.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(illust.title, style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 10),
                  _image(context),
                  if (illust.pageCount > 1) ...[
                    const SizedBox(height: 6),
                    Text(l10n.plugin_pixiv_pages(illust.pageCount), style: theme.textTheme.bodySmall),
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
    final avatar = illust.userAvatarUrl;
    final date = illust.createdAt;

    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PixivUserScreen(userId: illust.userId)),
          ),
          child: Row(
            children: [
              ClipOval(
                child: avatar == null
                    ? FallbackAvatar(
                        seed: '${illust.userId}',
                        displayName: illust.userName,
                        size: 32,
                        accent: theme.colorScheme.primary)
                    : ExtendedImage.network(
                        avatar,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        headers: pixivImageHeaders,
                        cacheWidth: (32 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                      ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(illust.userName,
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (date != null) Text(createCompactDate(date), style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _image(BuildContext context) {
    final radius = tweetMediaRadiusOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final scale = MediaQuery.devicePixelRatioOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 1,
        child: ExtendedImage.network(
          illust.thumbnailUrl,
          fit: BoxFit.cover,
          headers: pixivImageHeaders,
          cacheWidth: (width * scale).ceil(),
        ),
      ),
    );
  }
}
