import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:xta/client/client.dart';
import 'package:xta/group/feed_read_position.dart';
import 'package:xta/profile/profile.dart';
import 'package:xta/plugins/reddit/reddit_interleaved.dart';
import 'package:xta/tweet/interleaved_items.dart';
import 'package:xta/tweet/paginated_tweet_list.dart';
import 'package:xta/ui/errors.dart';
import 'package:xta/user.dart';
import 'package:xta/generated/l10n.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import '../constants.dart';

final UserWithExtra user = UserWithExtra.fromArguments(idStr: "1", possiblySensitive: false, screenName: "ForYou");

class ForYouTweets extends StatefulWidget {
  final TweetFeedController feed;
  final String type;
  final bool includeReplies;
  final BasePrefService pref;

  const ForYouTweets(this.feed,
      {super.key, required this.type, required this.includeReplies, required this.pref});

  @override
  State<ForYouTweets> createState() => _ForYouTweetsState();
}

class _ForYouTweetsState extends State<ForYouTweets> with AutomaticKeepAliveClientMixin<ForYouTweets> {
  static const int pageSize = 20;
  int loadTweetsCounter = 0;
  @override
  bool get wantKeepAlive => true;

  /// Reddit posts mixed into this timeline, when the reader asked for them.
  ///
  /// Loaded once per mount and slotted between the chains by date: For you
  /// pages on X's cursor, which nothing else can page on, and a subreddit
  /// publishes at its own rate rather than X's.
  List<InterleavedItem> _redditItems = const [];

  // Reading position: boundary loaded once per mount and frozen so the
  // "You're caught up" divider never moves mid-session.
  FeedReadPosition? _lastSeen;
  bool _readPositionLoadStarted = false;
  bool _readPositionReady = false;
  bool _caughtUpRestoreEvaluated = false;
  bool _userHasScrolled = false;
  String? _lastRecordedChainId;
  List<TweetChain>? _pendingFirstPage;
  final GlobalKey _caughtUpKey = GlobalKey();
  ScrollController? _innerScrollController;

  @override
  void initState() {
    super.initState();
    widget.feed.pageCapProvider = _zenPageCap;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRedditPosts());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _innerScrollController = PrimaryScrollController.maybeOf(context);
    _maybeLoadReadPosition();
  }

  Future<void> _loadRedditPosts() async {
    final items = await loadRedditInterleaved(context, redditHomeSubreddits(context));
    // Assigned even when empty: turning the mix off or losing every subreddit
    // must clear prior cards, not leave them stuck on For You.
    if (mounted) {
      setState(() => _redditItems = items);
    }
  }

  // In zen mode the feed is finite: pagination pauses after this many pages
  // per session. `null` disables the cap when zen mode is off.
  int? _zenPageCap() {
    if (widget.pref.get(optionZenMode) != true) {
      return null;
    }
    return widget.pref.get<int>(optionZenModePageCap);
  }

  bool get _tracksReadPosition => widget.pref.get(optionFeedReadingPosition) == true;

  bool _isSeen(TweetChain chain) => _lastSeen != null && isChainSeen(chain, _lastSeen!);

  void _maybeLoadReadPosition() {
    if (_readPositionLoadStarted || !_tracksReadPosition) {
      return;
    }
    _readPositionLoadStarted = true;
    readFeedReadPosition(feedKeyForYou).then((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastSeen = position;
        _readPositionReady = true;
      });
      // First page may have arrived while the DB read was in flight, or the
      // controller may still hold items from a prior tab visit.
      final pending = _pendingFirstPage;
      _pendingFirstPage = null;
      final items = pending ?? widget.feed.items;
      if (items != null && items.isNotEmpty) {
        _onFirstPageLoaded(items);
      }
    });
  }

  void incrementLoadTweetsCounter() {
    ++loadTweetsCounter;
  }

  int getLoadTweetsCounter() {
    return loadTweetsCounter;
  }

  Future<TweetPageResult> _loadTweets(String? cursor) async {
    final result = await Twitter.getTimelineTweets(
      user.idStr!,
      widget.type,
      cursor: cursor,
      count: pageSize,
      includeReplies: widget.includeReplies,
      getTweetsCounter: getLoadTweetsCounter,
      incrementTweetsCounter: incrementLoadTweetsCounter,
    );
    if (cursor == null && _tracksReadPosition) {
      if (_readPositionReady) {
        _onFirstPageLoaded(result.chains);
      } else {
        _pendingFirstPage = result.chains;
      }
    }
    return (chains: result.chains, nextCursor: result.cursorBottom);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification && notification.direction != ScrollDirection.idle) {
      _userHasScrolled = true;
    }
    if (notification is! ScrollEndNotification) {
      return false;
    }
    final metrics = notification.metrics;
    if (_tracksReadPosition && metrics.hasPixels && metrics.pixels <= feedReadPositionTopThresholdPx) {
      final items = widget.feed.items;
      if (items != null && items.isNotEmpty) {
        _recordReadPosition(items);
      }
    }
    return false;
  }

  ScrollPosition? get _scrollPosition {
    final controller = _innerScrollController;
    if (controller == null || controller.positions.length != 1) {
      return null;
    }
    return controller.positions.first;
  }

  bool get _atTop {
    final position = _scrollPosition;
    return position == null || position.pixels <= feedReadPositionTopThresholdPx;
  }

  void _recordReadPosition(List<TweetChain> threads) {
    final newest = newestRecordableChain(threads);
    if (newest == null || newest.id == _lastRecordedChainId) {
      return;
    }
    _lastRecordedChainId = newest.id;
    writeFeedReadPosition(feedKeyForYou, newest).catchError((_) {});
  }

  void _onFirstPageLoaded(List<TweetChain> threads) {
    if (!_caughtUpRestoreEvaluated) {
      _caughtUpRestoreEvaluated = true;
      final boundary = _lastSeen == null ? null : caughtUpBoundaryIndex(threads, _lastSeen!);
      if (boundary != null) {
        _scheduleCaughtUpRestore(boundary, threads.length);
        return;
      }
    }
    if (_atTop) {
      _recordReadPosition(threads);
    }
  }

  void _scheduleCaughtUpRestore(int index, int itemCount, [int attempts = 0]) {
    if (_userHasScrolled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _userHasScrolled || attempts >= maxCaughtUpRestoreFrames) {
        return;
      }
      final position = _scrollPosition;
      if (position == null || !position.haveDimensions || !widget.feed.hasItems) {
        _scheduleCaughtUpRestore(index, itemCount, attempts + 1);
        return;
      }
      final divider = _caughtUpKey.currentContext;
      if (divider != null) {
        Scrollable.ensureVisible(divider, alignment: 0.02);
        return;
      }
      if (attempts + 1 < maxCaughtUpRestoreFrames) {
        _scheduleCaughtUpRestore(index, itemCount, attempts + 1);
        return;
      }
      final estimated = (position.maxScrollExtent * index / itemCount).clamp(0.0, position.maxScrollExtent);
      position.jumpTo(estimated);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MultiProvider(
        providers: [
          ChangeNotifierProvider<TweetContextState>(
              create: (_) => TweetContextState(PrefService.of(context).get(optionTweetsHideSensitive)))
        ],
        builder: (context, child) {
          return Consumer<TweetContextState>(builder: (context, model, child) {
            if (model.hideSensitive && (user.possiblySensitive ?? false)) {
              return EmojiErrorWidget(
                emoji: '🍆🙈🍆',
                message: L10n.current.possibly_sensitive,
                errorMessage: L10n.current.possibly_sensitive_profile,
                onRetry: () async => model.setHideSensitive(false),
                retryText: L10n.current.yes_please,
              );
            }

            return NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: PaginatedTweetList(
                feed: widget.feed,
                loadPage: _loadTweets,
                interleaved: _redditItems,
                username: user.screenName,
                onRefresh: () async {},
                firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets,
                newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
                emptyMessage: L10n.of(context).unable_to_load_the_tweets_for_the_feed,
                isSeen: _tracksReadPosition && _lastSeen != null ? _isSeen : null,
                caughtUpDividerKey: _caughtUpKey,
              ),
            );
          });
        });
  }
}
