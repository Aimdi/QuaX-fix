import 'package:extended_image/extended_image.dart';
import 'package:ffcache/ffcache.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/plugins/reddit/reddit_avatar.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';
import 'package:quax/utils/cache.dart';

/// How long a subreddit's picture is kept before it is looked up again.
/// Community artwork changes about as often as a logo does.
const Duration kRedditIconExpiry = Duration(days: 7);

/// The subreddit pictures known this session.
///
/// Finding one costs a page fetch, so it happens once per subreddit and is
/// remembered — in memory for the session and on disk between them. An empty
/// string stands for "asked, and there is none", which is worth remembering as
/// much as a hit: it is what stops a subreddit without artwork from being
/// looked up again on every card.
class RedditIcons {
  final RedditClient client;
  final FFCache _cache = FFCache(name: redditIconsCacheName);
  final Map<String, Future<String?>> _pending = {};

  RedditIcons(this.client);

  Future<String?> iconFor(String subreddit) {
    final key = subreddit.toLowerCase();

    return _pending.putIfAbsent(key, () async {
      final cached = await _cache.getOrCreateAsJSON(
        key,
        kRedditIconExpiry,
        () async => await client.fetchSubredditIcon(subreddit) ?? '',
      );

      return cached.isEmpty ? null : cached;
    });
  }
}

/// A subreddit's picture, the way Reddit's own apps show it.
///
/// Falls back to the generated tile when the subreddit has no artwork, so the
/// row always has something in it and two subreddits never look alike.
/// Deliberately keyed on the subreddit and not the author: a timeline of
/// communities should be scannable by community.
class RedditSubredditAvatar extends StatefulWidget {
  final String subreddit;
  final double size;

  const RedditSubredditAvatar({super.key, required this.subreddit, this.size = 40});

  @override
  State<RedditSubredditAvatar> createState() => _RedditSubredditAvatarState();
}

class _RedditSubredditAvatarState extends State<RedditSubredditAvatar> {
  String? _icon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void didUpdateWidget(RedditSubredditAvatar old) {
    super.didUpdateWidget(old);
    if (old.subreddit != widget.subreddit) {
      _icon = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (!mounted || widget.subreddit.isEmpty) {
      return;
    }

    final icon = await context.read<RedditIcons>().iconFor(widget.subreddit);
    if (mounted && icon != null) {
      setState(() => _icon = icon);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    // The generated tile is not a placeholder to be swapped out — it is what a
    // subreddit without artwork keeps. Showing it until the answer arrives
    // means the row never changes height or jumps.
    if (icon == null) {
      return RedditAvatar(name: 'r/${widget.subreddit}', size: widget.size);
    }

    // Contained, not cropped, on a filled square. A community logo is usually
    // drawn with margins of its own and is rarely square — cover cut the edges
    // off exactly the part that identifies it.
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: redditAvatarBorder(widget.size),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExtendedImage.network(
        icon,
        fit: BoxFit.contain,
        loadStateChanged: (state) => state.extendedImageLoadState == LoadState.completed
            ? null
            : RedditAvatar(name: 'r/${widget.subreddit}', size: widget.size),
      ),
    );
  }
}
