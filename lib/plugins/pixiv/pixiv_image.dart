import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';

/// Pixiv CDN image decoded at the size it is painted — Referer + cacheWidth.
///
/// Without [cacheWidth], every masonry cell decodes a full `medium`/`large`
/// bitmap into the shared image cache and scroll jank follows. Pixez-style
/// clients always resize at decode time for waterfall tiles.
class PixivNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final LoadStateChanged? loadStateChanged;

  const PixivNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.loadStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (cacheWidth != null || cacheHeight != null) {
      return ExtendedImage.network(
        url,
        fit: fit,
        cache: true,
        headers: pixivImageHeaders,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        loadStateChanged: loadStateChanged,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final width = maxW.isFinite && maxW > 0
            ? (maxW * MediaQuery.devicePixelRatioOf(context)).ceil()
            : null;
        return ExtendedImage.network(
          url,
          fit: fit,
          cache: true,
          headers: pixivImageHeaders,
          cacheWidth: width,
          loadStateChanged: loadStateChanged,
        );
      },
    );
  }
}

/// Warm disk cache for thumbs the masonry is about to show (network only).
Future<void> prefetchPixivThumbs(
  BuildContext context,
  Iterable<PixivIllust> illusts, {
  int max = 12,
}) async {
  for (final illust in illusts.take(max)) {
    if (!context.mounted) {
      return;
    }
    final provider = ExtendedNetworkImageProvider(
      illust.thumbnailUrl,
      headers: pixivImageHeaders,
      cache: true,
    );
    await precacheImage(provider, context).catchError((_) {});
  }
}
