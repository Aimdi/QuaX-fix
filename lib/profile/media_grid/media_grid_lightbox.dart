import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/constants.dart';
import 'package:quax/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:quax/status.dart';
import 'package:quax/tweet/_media.dart';

/// Fullscreen swipeable viewer paging across all loaded items of a media
/// grid, with an "open post" escape hatch to the tweet a page belongs to.
///
/// For paginated grids it listens to the [PagingController] so pages fetched
/// while swiping (via [TweetMediaView.onNearEnd]) appear seamlessly; static
/// grids pass their fixed item list instead.
class MediaGridLightbox extends StatefulWidget {
  final PagingController<int, MediaGridItem>? controller;
  final List<MediaGridItem> staticItems;
  final int initialIndex;

  const MediaGridLightbox({super.key, this.controller, this.staticItems = const [], required this.initialIndex});

  @override
  State<MediaGridLightbox> createState() => _MediaGridLightboxState();
}

class _MediaGridLightboxState extends State<MediaGridLightbox> {
  List<MediaGridItem> get _items => widget.controller?.value.items ?? widget.staticItems;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onPagingChanged);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onPagingChanged);
    super.dispose();
  }

  void _onPagingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openPost(MediaViewEntry entry) {
    Navigator.pushNamed(
      context,
      routeStatus,
      arguments: StatusScreenArguments(
        id: entry.tweetId!,
        username: entry.username,
        tweetOpened: true,
        initialMediaIndex: entry.mediaIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweetMediaView.entries(
      initialIndex: widget.initialIndex,
      entries: [
        for (final item in _items)
          (media: item.media, username: item.username, tweetId: item.tweetId, mediaIndex: item.mediaIndex)
      ],
      onOpenPost: _openPost,
      onNearEnd: widget.controller?.fetchNextPage,
    );
  }
}

void openMediaLightbox(BuildContext context,
    {PagingController<int, MediaGridItem>? controller,
    List<MediaGridItem> staticItems = const [],
    required int initialIndex}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          MediaGridLightbox(controller: controller, staticItems: staticItems, initialIndex: initialIndex),
    ),
  );
}
