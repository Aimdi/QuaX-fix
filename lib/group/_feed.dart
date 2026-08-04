import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/feed_catch_up.dart';
import 'package:quax/group/feed_read_position.dart';
import 'package:quax/group/feed_session_cache.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/profile/media_grid/media_grid.dart';
import 'package:quax/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:logging/logging.dart';
import 'package:quax/plugins/reddit/reddit_interleaved.dart';
import 'package:quax/plugins/substack/substack_client.dart';
import 'package:quax/plugins/substack/substack_post_card.dart';
import 'package:quax/plugins/substack/substack_store.dart';
import 'package:quax/profile/profile_feed_settings.dart';
import 'package:quax/tweet/catch_up_split.dart';
import 'package:quax/tweet/interleaved_items.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/tweet_context_scope.dart';
import 'package:quax/utils/iterables.dart';
import 'package:quax/utils/paging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quax/utils/urls.dart';
import 'package:quax/group/custom_feed_rules.dart';
import 'package:quax/group/feed_rules.dart';

/// One chunk's contribution to a feed page: its chains, whether its gap-fill
/// ran out of allowance, and whether X answered with posts from outside the
/// chunk's own subscriptions.
typedef _ChunkResult = ({List<TweetChain> chains, bool gapCapped, bool unrelated});

Iterable<BigInt> _tweetIdsOf(Iterable<TweetChain> chains) =>
    chains.expand((c) => c.tweets).map((t) => t.idStr).whereType<String>().map(BigInt.tryParse).whereType<BigInt>();

BigInt? _newestTweetIdOf(Iterable<TweetChain> chains) =>
    _tweetIdsOf(chains).fold<BigInt?>(null, (max, id) => max == null || id > max ? id : max);

BigInt? _oldestTweetIdOf(Iterable<TweetChain> chains) =>
    _tweetIdsOf(chains).fold<BigInt?>(null, (min, id) => min == null || id < min ? id : min);

class SubscriptionGroupFeed extends StatefulWidget {
  final SubscriptionGroupGet group;
  final List<SubscriptionGroupFeedChunk> chunks;
  final bool includeReplies;
  final bool includeRetweets;
  final bool mediaOnly;
  // When non-null, the PagingController and scroll offset are stored in the
  // app-scoped FeedSessionCache under this key, so pop+push of the same route
  // restores tweets and scroll position. When null, state is local to this
  // State and disposed normally — used by home-tab usages, which are kept
  // alive by AutomaticKeepAliveClientMixin in the shell.
  final String? cacheKey;
  // Cached tweets to show immediately while the first page loads, seeded by the
  // caller (e.g. the All/Following feed reuses the preview it already read while
  // its subscriptions were loading). Refined to this feed's own chunks once read.
  final List<TweetChain>? initialPreview;
  // When those cached tweets were saved, so a failed load can say how old the
  // posts it falls back on are.
  final DateTime? initialPreviewCachedAt;

  /// Substack publications in this group. They are members like any other, but
  /// they have their own source and their own pagination, so they are fetched
  /// beside the X search rather than inside it.
  final List<SubstackSubscription> publications;

  /// Subreddits in this group, fetched beside the X search for the same reason
  /// as the publications: their own source, their own pagination.
  final List<RedditSubscription> subreddits;

  const SubscriptionGroupFeed(
      {super.key,
      required this.group,
      required this.chunks,
      required this.includeReplies,
      required this.includeRetweets,
      required this.mediaOnly,
      this.cacheKey,
      this.initialPreview,
      this.initialPreviewCachedAt,
      this.publications = const [],
      this.subreddits = const []});

  @override
  State<SubscriptionGroupFeed> createState() => _SubscriptionGroupFeedState();
}

class _SubscriptionGroupFeedState extends State<SubscriptionGroupFeed> {
  late final TweetFeedController _feedController;
  // Grid-mode paging, created on first use. Kept separately from the tweet
  // list's controller so toggling the media filter swaps views without
  // refetching either of them.
  CursorPagingController<String, MediaGridItem>? _mediaPaging;
  final Set<String> _seenMediaKeys = <String>{};
  FeedSessionCache? _cache;
  ScrollController? _innerScrollController;
  bool _scrollRestoreScheduled = false;
  // Cached tweets shown while the first page loads, so opening the feed reveals
  // its previously-loaded content instead of a full-screen spinner. They are
  // also the fallback when the first page fails outright.
  List<TweetChain>? _cachedPreview;
  DateTime? _cachedPreviewAt;
  // Set when a first page stopped filling the gap between the newest posts and
  // the stored ones because it ran out of allowance. The catch-up card must not
  // claim the reader is finished when this is true.
  bool _gapCapped = false;

  // Reading position: the boundary is loaded once per mount and stays frozen,
  // so the "You're caught up" divider never moves mid-session.
  FeedReadPosition? _lastSeen;
  bool _readPositionLoadStarted = false;
  bool _caughtUpRestoreEvaluated = false;
  bool _userHasScrolled = false;
  String? _lastRecordedChainId;
  final GlobalKey _caughtUpKey = GlobalKey();

  static final _log = Logger('SubscriptionGroupFeed');

  bool get _usesCache => widget.cacheKey != null;

  /// Substack posts loaded for this group's publications, newest first.
  ///
  /// Substack pages by offset and X by cursor, so the two cannot share one
  /// paginator. These are fetched once per mount and slotted among the chains
  /// by date; scrolling further into X's history does not need more of them,
  /// because a newsletter publishes a handful of posts a week, not a page.
  List<InterleavedItem> _substackItems = const [];

  /// Reddit posts for this group's subreddits, newest first.
  List<InterleavedItem> _redditItems = const [];

  /// The two sources merged, rebuilt only when one of them arrives. Built in
  /// `build` it was a fresh list every frame, so nothing downstream could tell
  /// by identity that the interleave had not changed.
  List<InterleavedItem> _interleaved = const [];

  void _mergeInterleaved() => _interleaved = [..._substackItems, ..._redditItems];

  Future<void> _loadRedditPosts() async {
    if (widget.mediaOnly) {
      return;
    }

    // The group's own subreddits, plus every followed one when this is the
    // combined feed and the reader asked for Reddit in it.
    final names = {
      ...widget.subreddits.map((e) => e.name),
      if (widget.group.id == '-1') ...redditHomeSubreddits(context),
    }.toList(growable: false);

    final items = await loadRedditInterleaved(context, names);
    if (mounted && items.isNotEmpty) {
      setState(() {
        _redditItems = items;
        _mergeInterleaved();
      });
    }
  }

  Future<void> _loadSubstackPosts() async {
    if (widget.publications.isEmpty || widget.mediaOnly) {
      return;
    }

    // A reader who switched the plugin off still had every publication fetched
    // on each mount of this feed.
    if (PrefService.of(context, listen: false).get<bool>(optionPluginSubstackEnabled) != true) {
      return;
    }

    final client = context.read<SubstackClient>();

    // Fetched together rather than one after another: the wait used to be the
    // sum of the publications instead of the slowest one.
    final perPublication = await Future.wait(widget.publications.map((publication) async {
      final items = <InterleavedItem>[];

      try {
        final posts = await client.fetchPosts(publicationOf(publication), limit: substackFeedPageSize);
        for (final post in posts) {
          final date = post.publishedAt;
          if (date == null) {
            continue;
          }
          items.add((
            date: date,
            build: (context) => SubstackPostCard(post: post, logoUrl: publication.logoUrl),
          ));
        }
      } catch (e) {
        // One unreachable publication must not empty the whole feed of the
        // others, nor replace a working timeline with an error screen.
        _log.warning('Unable to load Substack posts for ${publication.id}: $e');
      }

      return items;
    }));

    if (mounted) {
      setState(() {
        _substackItems = perPublication.expand((e) => e).toList();
        _mergeInterleaved();
      });
    }
  }

  // Chronological feeds only: in popular order a "seen up to" boundary is
  // meaningless, and the media grid shares this loader but shows no divider.
  bool get _supportsReadPosition => !widget.group.popular && !widget.mediaOnly;

  /// Catch-up mode: this feed shows only what is new since the reader's last
  /// position and stops there. Per feed, off unless turned on for this one.
  bool get _catchUpEnabled =>
      _supportsReadPosition &&
      PrefService.of(context, listen: false).get(feedCatchUpModeKey(widget.group.id)) == true;

  bool get _tracksReadPosition =>
      _supportsReadPosition &&
      (PrefService.of(context, listen: false).get(optionFeedReadingPosition) == true || _catchUpEnabled);

  bool _isSeen(TweetChain chain) => _lastSeen != null && isChainSeen(chain, _lastSeen!);

  /// The stop pagination applies in catch-up mode, or null when the mode is off
  /// or there is no recorded position yet — in which case the feed pages as it
  /// always did rather than hiding posts on a guess.
  SeenChainPredicate? _catchUpPredicate() {
    if (!mounted || _lastSeen == null || !_catchUpEnabled) {
      return null;
    }
    return _isSeen;
  }

  /// The reader scrolled to the end of what was new. This is the only place
  /// catch-up mode moves the read position: everything above the card has been
  /// on screen, which a scroll back to the top does not prove.
  void _recordCaughtUp() {
    final items = _feedController.items;
    if (items == null || items.isEmpty) {
      return;
    }
    _recordReadPosition(items);
  }

  CursorPagingController<String, MediaGridItem> get _mediaController =>
      _mediaPaging ??= CursorPagingController(_loadMediaPage);

  @override
  void initState() {
    super.initState();
    if (_usesCache) {
      _cache = context.read<FeedSessionCache>();
      _feedController = _cache!.getOrCreateController(widget.cacheKey!);
    } else {
      _feedController = TweetFeedController();
    }
    _feedController.pageCapProvider = _zenPageCap;
    _feedController.catchUpPredicateProvider = _catchUpPredicate;
    // Cached (pop/push-restored) controllers already hold their tweets; only a
    // fresh controller needs the preview while it loads the first page.
    _cachedPreview = widget.initialPreview;
    _cachedPreviewAt = widget.initialPreviewCachedAt;
    // The screen above may already have read and decoded the cached chunks for
    // us; doing it again here decoded the same rows a second time, on the UI
    // isolate, in the frames the reader is waiting on.
    if (!_feedController.hasItems && (widget.initialPreview?.isEmpty ?? true)) {
      _loadPreview();
    }
    _loadSubstackPosts();
    _loadRedditPosts();
  }

  Future<void> _loadPreview() async {
    var repository = await Repository.readOnly();
    var stored = await readCachedChainsForHashes(repository, widget.chunks.map((e) => e.hash));
    var cached = filterHiddenRetweets(stored.chains, await hiddenRetweetScreenNames());
    cached = filterHiddenReplies(cached, await hiddenReplyScreenNames());
    if (!mounted) return;
    setState(() {
      _cachedPreview = cached;
      _cachedPreviewAt = stored.cachedAt;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inside NestedScrollView's body, PrimaryScrollController is the inner
    // controller PagedListView attaches to, and the one we need for jumpTo().
    _innerScrollController = PrimaryScrollController.maybeOf(context);
    _maybeLoadReadPosition();
    if (!_usesCache) return;
    _maybeRestoreScrollOffset();
  }

  void _maybeLoadReadPosition() {
    if (_readPositionLoadStarted || !_tracksReadPosition) {
      return;
    }
    _readPositionLoadStarted = true;
    readFeedReadPosition(widget.group.id).then((position) {
      if (mounted && position != null) {
        setState(() => _lastSeen = position);
      }
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Any user-driven scroll cancels an in-flight caught-up restore, so it
    // never yanks the list out from under the reader.
    if (notification is UserScrollNotification && notification.direction != ScrollDirection.idle) {
      _userHasScrolled = true;
    }
    if (notification is! ScrollEndNotification) {
      return false;
    }
    final metrics = notification.metrics;
    if (_usesCache && metrics.hasPixels) {
      _cache!.saveOffset(widget.cacheKey!, metrics.pixels);
    }
    // Scrolled back up to the top: everything currently loaded counts as read.
    // Catch-up mode does not take that bet — being at the top says nothing
    // about what was read, and there the position is written only on reaching
    // the end of the new posts.
    if (_tracksReadPosition &&
        !_catchUpEnabled &&
        metrics.hasPixels &&
        metrics.pixels <= feedReadPositionTopThresholdPx) {
      final items = _feedController.items;
      if (items != null && items.isNotEmpty) {
        _recordReadPosition(items);
      }
    }
    return false;
  }

  // The single attached scroll position, or null when the controller has none
  // or — inside a NestedScrollView during reload/tab transitions — more than
  // one. Reading `controller.position` with several attached asserts and would
  // crash, so every position access goes through here.
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
    final newest = threads.where((c) => c.tweets.firstOrNull?.createdAt != null).firstOrNull;
    if (newest == null || newest.id == _lastRecordedChainId) {
      return;
    }
    _lastRecordedChainId = newest.id;
    // Fire-and-forget: a failed position save must never surface as an
    // unhandled async error.
    writeFeedReadPosition(widget.group.id, newest).catchError((_) {});
  }

  // Called with each finalized first page. The first one decides between
  // restoring the caught-up position (there are unread posts above it) and
  // recording; later ones (soft refreshes) record only while at the top, so
  // an app-bar refresh fired mid-scroll can't mark unseen posts as read.
  void _onFirstPageLoaded(List<TweetChain> threads) {
    if (!_caughtUpRestoreEvaluated) {
      _caughtUpRestoreEvaluated = true;
      final sessionOffset = _usesCache ? _cache!.readOffset(widget.cacheKey!) : null;
      final boundary = _lastSeen == null ? null : caughtUpBoundaryIndex(threads, _lastSeen!);
      if (boundary != null && (sessionOffset == null || sessionOffset <= 0)) {
        _scheduleCaughtUpRestore(boundary, threads.length);
        return; // The newer posts haven't been seen yet — don't record.
      }
    }
    if (_atTop) {
      _recordReadPosition(threads);
    }
  }

  // Restore near the last-read chain once its row is laid out. Waits (bounded)
  // for the divider's key to resolve, then brings it just under the app bar in
  // a single scroll. If it never builds within the frame budget it does one
  // proportional jump and stops — deliberately gentle, so it never jump-fights
  // the user's own scrolling and never touches a multi-position controller.
  void _scheduleCaughtUpRestore(int index, int itemCount, [int attempts = 0]) {
    if (_userHasScrolled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _userHasScrolled || attempts >= maxCaughtUpRestoreFrames) {
        return;
      }
      final position = _scrollPosition;
      // Wait until the real list (not the preview) is mounted and laid out.
      if (position == null || !position.haveDimensions || !_feedController.hasItems) {
        _scheduleCaughtUpRestore(index, itemCount, attempts + 1);
        return;
      }
      final divider = _caughtUpKey.currentContext;
      if (divider != null) {
        Scrollable.ensureVisible(divider, alignment: 0.02);
        return;
      }
      // Divider not built yet: keep waiting a few frames, then settle for a
      // one-shot proportional estimate rather than jumping every frame.
      if (attempts + 1 < maxCaughtUpRestoreFrames) {
        _scheduleCaughtUpRestore(index, itemCount, attempts + 1);
        return;
      }
      final estimated = (position.maxScrollExtent * index / itemCount).clamp(0.0, position.maxScrollExtent);
      position.jumpTo(estimated);
    });
  }

  void _maybeRestoreScrollOffset() {
    if (_scrollRestoreScheduled) return;
    _scrollRestoreScheduled = true;
    final saved = _cache!.readOffset(widget.cacheKey!);
    if (saved == null || saved <= 0) return;
    _scheduleRestore(saved);
  }

  // The cached items render and lay out across the first few frames, so the
  // ScrollPosition may not be attached yet on the very first post-frame.
  // Keep scheduling post-frame callbacks until the scrollable reports stable
  // dimensions, then jump. Terminates via `mounted` when the widget unmounts.
  void _scheduleRestore(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = _scrollPosition;
      if (position == null || !position.haveDimensions) {
        _scheduleRestore(offset);
        return;
      }
      position.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _mediaPaging?.dispose();
    if (!_usesCache) {
      _feedController.dispose();
    }
    // When cached, the FeedSessionCache owns the controller's lifecycle across
    // pop/push; PaginatedTweetList has already detached its own listener.
    super.dispose();
  }

  @override
  void didUpdateWidget(SubscriptionGroupFeed oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.includeReplies != widget.includeReplies ||
        oldWidget.includeRetweets != widget.includeRetweets ||
        oldWidget.group.popular != widget.group.popular ||
        oldWidget.group.custom != widget.group.custom ||
        feedRulesOf(oldWidget.group).cacheKey != feedRulesOf(widget.group).cacheKey ||
        !_chunksMatch(oldWidget.chunks, widget.chunks)) {
      _feedController.controller.refresh();
      _mediaPaging?.pagingController.refresh();
    }
  }

  bool _chunksMatch(List<SubscriptionGroupFeedChunk> a, List<SubscriptionGroupFeedChunk> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].hash != b[i].hash) return false;
    }
    return true;
  }

  Future<String> createCursor(Database repository) async {
    return (await repository.insert(tableFeedGroupCursor, {}, nullColumnHack: 'id')).toString();
  }

  bool feedContainsUnrelatedTweets(TweetStatus tweets, List<Subscription> users) {
    final screenNames = users.map((e) => e.screenName).toSet();
    return tweets.chains.any(
        (chain) => chain.tweets.any((tweet) => tweet.user != null && !screenNames.contains(tweet.user!.screenName)));
  }

  Future<void> showUnrelatedPostsInFeedWarning() async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("⚠️ ${L10n.of(context).feed_issue_detected}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.of(context).feed_contains_unrelated_tweets),
                SizedBox(height: Theme.of(context).textTheme.bodyMedium!.fontSize! * 2),
                PrefCheckbox(
                  title: Text(
                    L10n.of(context).never_show_again,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  pref: optionDisableWarningsForUnrelatedPostsInFeed,
                )
              ],
            ),
            actions: [
              TextButton(
                child: Text(L10n.of(context).more_info),
                onPressed: () async {
                  await openUri(context, "https://github.com/Teskann/QuaX/issues/26");
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              TextButton(
                child: Text(L10n.of(context).close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  String _buildSearchQuery(List<Subscription> users) {
    var query = '';

    var remainingLength = 512 - query.length;

    for (var user in users) {
      var queryToAdd = '';
      if (user is UserSubscription) {
        queryToAdd = 'from:${user.screenName}';
      } else if (user is SearchSubscription) {
        queryToAdd = '"${user.id}"';
      }

      // If we can add this user to the query and still be less than ~512 characters, do so
      if (query.length + queryToAdd.length < remainingLength) {
        if (query != '' && query.isNotEmpty) {
          query += ' OR ';
        }

        query += queryToAdd;
      } else {
        // Otherwise, add the search future and start a new one
        assert(false, 'should never reach here');
        query = queryToAdd;
      }
    }

    if (!widget.includeReplies) {
      query += ' -filter:replies ';
    }

    if (!widget.includeRetweets) {
      query += ' -filter:retweets ';
    } else {
      query += ' include:nativeretweets ';
    }

    return query;
  }

  /// Where a chunk's page starts: the stored chains to show under it (first
  /// page only) and the cursor the fresh search continues from.
  Future<({String? cursor, List<TweetChain> stored})> _chunkStart(
      Database repository, String hash, String? cursorKey) async {
    if (cursorKey != null) {
      // At the end of the current feed: the oldest chunk's cursor loads more.
      var rows = await repository.query(tableFeedGroupChunk,
          where: 'cursor_id = ? AND hash = ?', whereArgs: [int.parse(cursorKey), hash], limit: 1);
      return (cursor: rows.firstOrNull?['cursor_bottom'] as String?, stored: const <TweetChain>[]);
    }

    // The newest chunks we already have. Reading every stored row put a week of
    // accumulated JSON in front of the first paint, and the first page kept
    // growing until a pull-to-refresh cleared it.
    var rows = await repository.query(tableFeedGroupChunk,
        where: 'hash = ?', whereArgs: [hash], orderBy: 'created_at DESC', limit: maxCachedChunkRows);
    return (cursor: rows.firstOrNull?['cursor_top'] as String?, stored: chainsFromStoredChunks(rows));
  }

  Future<void> _storePage(Database repository, String nextCursor, String hash, TweetStatus page) async {
    if (page.chains.isEmpty) {
      return;
    }
    // The cursors ride along with the response, ready for the next paginate.
    await repository.insert(tableFeedGroupChunk, {
      'cursor_id': int.parse(nextCursor),
      'hash': hash,
      'cursor_top': page.cursorTop,
      'cursor_bottom': page.cursorBottom,
      'response': jsonEncode(page.chains.map((e) => e.toJson()).toList()),
    });
  }

  /// One chunk's share of a feed page: its stored chains, the fresh search, and
  /// the bounded gap-fill between the two.
  Future<_ChunkResult> _loadChunk(
      Database repository, String nextCursor, SubscriptionGroupFeedChunk chunk, String? cursorKey) async {
    // Leaving the feed used to pay for every remaining chunk and every gap-fill
    // page in full: the only mounted check was after the whole fan-out had
    // finished.
    if (!mounted) {
      return (chains: const <TweetChain>[], gapCapped: false, unrelated: false);
    }

    var start = await _chunkStart(repository, chunk.hash, cursorKey);
    var tweets = <TweetChain>[...start.stored];
    // Newest row first, so this is the newest stored post, and the gap-fill
    // below stops at the same place.
    var storedNewestId = _newestTweetIdOf(tweets);

    // Checked again here rather than only at the top: the stored-chunk read
    // above is an await, so this is the first point where the reader can
    // actually have left since the fan-out started.
    if (!mounted) {
      return (chains: tweets, gapCapped: false, unrelated: false);
    }

    var query = _buildSearchQuery(chunk.users);
    var page = await Twitter.searchTweets(query, widget.includeReplies, cursor: start.cursor);
    var unrelated = feedContainsUnrelatedTweets(page, chunk.users);
    tweets.addAll(page.chains);
    await _storePage(repository, nextCursor, chunk.hash, page);

    bool gapRemains() => feedGapRemains(
          storedNewestId: storedNewestId,
          oldestFetchedId: _oldestTweetIdOf(page.chains),
          cursorBottom: page.cursorBottom,
          pageHasChains: page.chains.isNotEmpty,
        );

    // A single fetch returns only the newest page, so a long absence leaves a
    // hole between it and the stored posts. Keep paging down until the fresh
    // content overlaps what was stored (bounded, so a week away can't trigger
    // dozens of requests).
    var gapFills = 0;
    while (mounted && gapFills < maxFeedGapFillPages && gapRemains()) {
      page = await Twitter.searchTweets(query, widget.includeReplies, cursor: page.cursorBottom);
      gapFills++;
      tweets.addAll(page.chains);
      await _storePage(repository, nextCursor, chunk.hash, page);
    }

    // Still ground to cover once the allowance ran out: the posts between here
    // and what was stored were never fetched, and nothing downstream may claim
    // the reader has seen them.
    return (chains: tweets, gapCapped: gapRemains(), unrelated: unrelated);
  }

  /// Search for our next "page" of tweets.
  ///
  /// Here, each page is actually a set of mappings, where the ID of each set is the hash of all the user IDs in that
  /// set. We store this along with the top and bottom pagination cursors, which we use to perform pagination for all
  /// sets at the same time, allowing us to create a feed made up of individual search queries.
  Future<TweetPageResult> _listTweets(String? cursorKey) async {
    var repository = await Repository.writable();
    var nextCursor = await createCursor(repository);

    // Wait for all our searches to complete, then build our list of tweet conversations.
    // The stored chunks and the fresh fetch overlap at their window boundaries,
    // so drop repeated chains before display.
    var result = await Future.wait(
        widget.chunks.map((chunk) => _loadChunk(repository, nextCursor, chunk, cursorKey)).toList());
    var threads = _sortChains(dedupeChainsById(result.expand((element) => element.chains).toList()));
    threads = filterHiddenRetweets(threads, await hiddenRetweetScreenNames());
    threads = filterHiddenReplies(threads, await hiddenReplyScreenNames());
    threads = applyCustomFeedRules(threads, feedRulesOf(widget.group));

    if (!mounted) {
      return (chains: <TweetChain>[], nextCursor: null);
    }

    if (PrefService.of(context, listen: false).get(optionZenMode) == true) {
      threads = _applyZenMode(threads);
    }

    if (result.any((e) => e.unrelated) &&
        !PrefService.of(context, listen: false).get(optionDisableWarningsForUnrelatedPostsInFeed)) {
      await showUnrelatedPostsInFeedWarning();
    }

    if (cursorKey == null) {
      _gapCapped = result.any((e) => e.gapCapped);
      // Catch-up mode neither restores to the divider (the page it is about to
      // show *is* the new posts) nor records anything here.
      if (_tracksReadPosition && !_catchUpEnabled) {
        _onFirstPageLoaded(threads);
      }
    }

    return (chains: threads, nextCursor: nextCursor);
  }

  static int _likesOf(TweetChain chain) => chain.tweets.firstOrNull?.favoriteCount ?? 0;

  /// Popular groups order the same recent window by likes; recent ones (the
  /// default) by date.
  List<TweetChain> _sortChains(List<TweetChain> chains) {
    if (!widget.group.popular) {
      return sortChainsNewestFirst(chains);
    }
    return chains.sorted((a, b) => _likesOf(b).compareTo(_likesOf(a))).toList();
  }

  // In zen mode the feed is finite: pagination pauses after this many pages
  // per session. `null` disables the cap when zen mode is off.
  int? _zenPageCap() {
    if (!mounted) {
      return null;
    }
    final prefs = PrefService.of(context, listen: false);
    if (prefs.get(optionZenMode) != true) {
      return null;
    }
    return prefs.get<int>(optionZenModePageCap);
  }

  /// Zen mode: a calm feed with no engagement-based ranking — strictly
  /// newest-first, keeping only each author's few most recent posts so no
  /// account can flood the page.
  List<TweetChain> _applyZenMode(List<TweetChain> chains) {
    final byAuthorCount = <String, int>{};
    final kept = <TweetChain>[];

    for (final chain in sortChainsNewestFirst(chains)) {
      final author = chain.tweets.firstOrNull?.user?.idStr;
      if (author == null) {
        kept.add(chain);
        continue;
      }
      final count = byAuthorCount[author] ?? 0;
      if (count < zenModeMaxTweetsPerAuthor) {
        byAuthorCount[author] = count + 1;
        kept.add(chain);
      }
    }

    return kept;
  }

  /// Loads a page for the media grid: same pages as the tweet list, mapped to
  /// their media entries.
  Future<CursorPage<String, MediaGridItem>> _loadMediaPage(String? cursor) async {
    if (cursor == null) {
      _seenMediaKeys.clear();
    }

    // A profile's lookahead costs one request per page; here every page is the
    // whole per-chunk fan-out, so the default of four turns one screenful of
    // thumbnails into five fan-outs. A media-sparse group shows an emptier
    // first grid in exchange, and fills as the reader scrolls.
    return mediaPageWithLookahead(cursor, _listTweets, _unseenMediaItems, maxLookahead: 1);
  }

  // Successive search windows overlap at their boundaries, so keep only media
  // entries not shown on an earlier page.
  List<MediaGridItem> _unseenMediaItems(List<TweetChain> chains) {
    return mediaItemsFromChains(chains)
        .where((m) => _seenMediaKeys.add('${m.tweetId}/${m.mediaIndex}'))
        .toList();
  }

  Widget _buildMediaGrid(BuildContext context) {
    return Scaffold(
      body: TweetContextScope(
        child: MediaGrid(
          controller: _mediaController.pagingController,
          firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets_for_the_feed,
          newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
          emptyMessage: L10n.of(context).could_not_find_any_posts_with_media,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A group is empty when it has nothing from *any* source. Testing only the
    // X chunks meant a group of nothing but subreddits reported itself empty
    // before its posts were ever asked for — the list below knows how to show
    // interleaved items with no chains, but never got the chance.
    if (widget.chunks.isEmpty && widget.publications.isEmpty && widget.subreddits.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(L10n.of(context).this_group_contains_no_subscriptions),
        ),
      );
    }

    if (widget.mediaOnly) {
      return _buildMediaGrid(context);
    }

    return Scaffold(
      body: TweetContextScope(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: PaginatedTweetList(
            feed: _feedController,
            loadPage: _listTweets,
            username: null,
            firstPagePreview: _cachedPreview,
            firstPagePreviewCachedAt: _cachedPreviewAt,
            onCaughtUp: _catchUpEnabled ? _recordCaughtUp : null,
            catchUpMayBeIncomplete: () => _gapCapped,
            onRefresh: () async {
              // Only this group's rows. The wipe used to take the whole table
              // with it, so pulling to refresh one feed made every other feed
              // refetch its first page from the network next time it opened.
              final hashes = widget.chunks.map((e) => e.hash).toList();
              if (hashes.isEmpty) {
                return;
              }

              var repository = await Repository.writable();
              await repository.delete(tableFeedGroupChunk,
                  where: 'hash IN (${List.filled(hashes.length, '?').join(', ')})', whereArgs: hashes);
            },
            firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets_for_the_feed,
            newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
            emptyMessage: L10n.of(context).could_not_find_any_tweets_from_the_last_7_days,
            isSeen: _tracksReadPosition && _lastSeen != null ? _isSeen : null,
            caughtUpDividerKey: _caughtUpKey,
            interleaved: _interleaved,
          ),
        ),
      ),
    );
  }
}
