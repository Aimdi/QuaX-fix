import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';
import 'package:quax/tweet/tweet_chrome.dart';
import 'package:quax/utils/urls.dart';

/// How tall a picture is allowed to get before it is cropped.
///
/// A phone-height meme would otherwise push everything after it off the screen,
/// and a feed where one post fills the viewport is not a feed.
const double kRedditMediaMaxHeight = 420;

/// The picture, video or link that goes with a Reddit post, at the width a
/// tweet's media gets rather than as a 70px thumbnail beside the title.
///
/// Only a real image is shown edge to edge. Reddit's video is a DASH manifest
/// and a gallery is a page, so neither can be rendered inline — those get a
/// link card that says where they lead, which is honest about what a tap will
/// do instead of showing a stretched placeholder.
class RedditPostMedia extends StatelessWidget {
  final RedditPost post;

  /// Inset around the media. The feed card lays its own text out flush with the
  /// screen edge and needs the gutter here; a thread screen already has one.
  final EdgeInsets padding;

  const RedditPostMedia({
    super.key,
    required this.post,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    final image = post.imageUrl;
    if (image != null) {
      return Padding(padding: padding, child: _RedditImage(url: image, blurred: post.over18));
    }

    final link = post.url;
    if (link != null && !post.isSelf) {
      return Padding(padding: padding, child: _RedditLinkCard(post: post, url: link));
    }

    return const SizedBox.shrink();
  }
}

/// How tall a picture inside a comment may get. Smaller than a post's, because
/// a reply is a reply — a full-height meme under one would bury the thread.
const double kRedditCommentMediaMaxHeight = 280;

/// Pictures and GIFs linked from a comment.
///
/// Deliberately Flutter's own [Image], not [ExtendedImage]: a GIF that does not
/// move is not a GIF, and animating multi-frame images is something the
/// framework's decoder does for free. Comment pictures are few and small, so
/// giving up the shared cache costs little.
class RedditCommentImages extends StatelessWidget {
  final List<String> urls;

  const RedditCommentImages({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final url in urls)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: kRedditCommentMediaMaxHeight),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (context, _, __) => _RedditBrokenImage(url: url),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A picture Reddit would not serve. The link survives, so it can still be
/// opened somewhere that will.
class _RedditBrokenImage extends StatelessWidget {
  final String url;

  const _RedditBrokenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => openUri(context, url),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              Uri.tryParse(url)?.host ?? url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedditImage extends StatefulWidget {
  final String url;
  final bool blurred;

  const _RedditImage({required this.url, required this.blurred});

  @override
  State<_RedditImage> createState() => _RedditImageState();
}

class _RedditImageState extends State<_RedditImage> {
  late bool _hidden = widget.blurred;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(tweetMediaRadiusOf(context)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: kRedditMediaMaxHeight, minHeight: 120),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            ExtendedImage.network(
              widget.url,
              width: double.infinity,
              fit: BoxFit.cover,
              loadStateChanged: _placeholderWhileLoading,
            ),
            if (_hidden) _cover(context),
          ],
        ),
      ),
    );
  }

  /// A tinted block rather than a spinner: the card keeps its shape while the
  /// picture arrives, so the feed does not jump as each one lands.
  Widget? _placeholderWhileLoading(ExtendedImageState state) {
    if (state.extendedImageLoadState == LoadState.completed) {
      return null;
    }

    return Container(
      height: 200,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: state.extendedImageLoadState == LoadState.failed
          ? Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
    );
  }

  Widget _cover(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Material(
            color: Colors.black26,
            child: InkWell(
              onTap: () => setState(() => _hidden = false),
              child: Center(
                child: Text(
                  L10n.of(context).possibly_sensitive,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a link, gallery or video post leads.
class _RedditLinkCard extends StatelessWidget {
  final RedditPost post;
  final String url;

  const _RedditLinkCard({required this.post, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = tweetMediaRadiusOf(context);
    final thumbnail = post.thumbnailUrl;

    return InkWell(
      onTap: () => openUri(context, url),
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            _leading(context, thumbnail),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  post.domain ?? Uri.tryParse(url)?.host ?? url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.open_in_new, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// The thumbnail when Reddit gave one, otherwise a square that says what kind
  /// of thing this is. A video gets a play badge over either.
  Widget _leading(BuildContext context, String? thumbnail) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnail != null)
            ExtendedImage.network(thumbnail, fit: BoxFit.cover)
          else
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.link, color: theme.colorScheme.onSurfaceVariant),
            ),
          if (post.isVideo)
            const Center(
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow, color: Colors.white, size: 22),
              ),
            ),
        ],
      ),
    );
  }
}
