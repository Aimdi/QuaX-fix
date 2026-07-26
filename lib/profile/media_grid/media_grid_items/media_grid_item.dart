import 'package:dart_twitter_api/api/media/data/media.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/tweet/_video_controls.dart';
import 'package:quax/utils/paging.dart';

part 'gif_grid_item.dart';
part 'video_grid_item.dart';
part 'photo_grid_item.dart';

sealed class MediaGridItem {
  // The source tweet when known, handed to the status screen as the instant
  // preview so opening a post from the lightbox never waits on a fetch.
  final TweetWithCard? tweet;
  final String tweetId;
  final String username;
  final String thumbnailUrl;
  final double aspectRatio;
  final int mediaIndex;
  final Media media;

  const MediaGridItem({
    this.tweet,
    required this.tweetId,
    required this.username,
    required this.thumbnailUrl,
    required this.aspectRatio,
    required this.mediaIndex,
    required this.media,
  });

  Widget toWidget(BuildContext context);
}

double _aspectRatioFor(Media m) {
  switch (m.type) {
    case 'photo':
      final w = m.sizes?.large?.w;
      final h = m.sizes?.large?.h;
      if (w == null || h == null || h == 0) return 1.0;
      return w / h;
    case 'video':
    case 'animated_gif':
      final ar = m.videoInfo?.aspectRatio;
      if (ar == null || ar.length < 2 || ar[1] == 0) return 1.0;
      return ar[0] / ar[1];
    default:
      return 1.0;
  }
}

MediaGridItem? _itemFor(Media m, String tweetId, String username, int mediaIndex, [TweetWithCard? tweet]) {
  final url = m.mediaUrlHttps;
  if (url == null) return null;
  final ar = _aspectRatioFor(m);
  switch (m.type) {
    case 'photo':
      return PhotoGridItem(
        tweet: tweet,
        tweetId: tweetId,
        username: username,
        thumbnailUrl: url,
        aspectRatio: ar,
        mediaIndex: mediaIndex,
        media: m,
      );
    case 'animated_gif':
      return GifGridItem(
        tweet: tweet,
        tweetId: tweetId,
        username: username,
        thumbnailUrl: url,
        aspectRatio: ar,
        mediaIndex: mediaIndex,
        media: m,
      );
    case 'video':
      return VideoGridItem(
        tweet: tweet,
        tweetId: tweetId,
        username: username,
        thumbnailUrl: url,
        aspectRatio: ar,
        mediaIndex: mediaIndex,
        media: m,
      );
    default:
      return null;
  }
}

/// Which media a grid shows.
///
/// Animated GIFs are served as video by X and play like one, so they belong
/// with the videos rather than in a category of their own.
enum MediaFilter {
  all,
  photos,
  videos;

  bool accepts(MediaGridItem item) => switch (this) {
        MediaFilter.all => true,
        MediaFilter.photos => item is PhotoGridItem,
        MediaFilter.videos => item is VideoGridItem || item is GifGridItem,
      };
}

CursorPage<String, MediaGridItem> mediaPageFromStatus(TweetStatus status, String? cursor) {
  final next = status.cursorBottom;
  // X repeats the bottom cursor once a timeline has no more pages. That does
  // mark the end, but the page it arrived with still holds real media —
  // discarding it lost the last screenful of a profile's media.
  final atEnd = next == null || next == cursor;
  return (items: mediaItemsFromChains(status.chains), nextCursor: atEnd ? null : next);
}

/// A page of tweets and where the next one starts.
typedef ChainPage = ({List<TweetChain> chains, String? nextCursor});

/// Loads media pages until one carries something.
///
/// Media posts are sparse: a page of twenty text posts maps to no media at all,
/// and an empty page is how the paging controller is told a feed has ended. So
/// a few more pages are pulled before giving that answer.
Future<CursorPage<String, MediaGridItem>> mediaPageWithLookahead(
  String? cursor,
  Future<ChainPage> Function(String? cursor) fetch,
  List<MediaGridItem> Function(List<TweetChain> chains) itemsOf, {
  int maxLookahead = 4,
}) async {
  var result = await fetch(cursor);
  var items = itemsOf(result.chains);

  var lookahead = 0;
  while (items.isEmpty && result.chains.isNotEmpty && result.nextCursor != null && lookahead < maxLookahead) {
    result = await fetch(result.nextCursor);
    items = itemsOf(result.chains);
    lookahead++;
  }

  return (items: items, nextCursor: result.nextCursor);
}

List<MediaGridItem> mediaItemsFromChains(List<TweetChain> chains) {
  final out = <MediaGridItem>[];
  for (final chain in chains) {
    for (final tweet in chain.tweets) {
      final medias = tweet.extendedEntities?.media;
      if (medias == null || medias.isEmpty) continue;
      final tweetId = tweet.idStr;
      final username = tweet.user?.screenName;
      if (tweetId == null || username == null) continue;
      for (var i = 0; i < medias.length; i++) {
        final item = _itemFor(medias[i], tweetId, username, i, tweet);
        if (item != null) out.add(item);
      }
    }
  }
  return out;
}
