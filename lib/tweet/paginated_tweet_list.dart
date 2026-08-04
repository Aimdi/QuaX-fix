import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/feed_refresh_controller.dart';
import 'package:quax/tweet/cached_tweet_list.dart';
import 'package:quax/tweet/catch_up_split.dart';
import 'package:quax/tweet/conversation.dart';
import 'package:quax/tweet/interleaved_items.dart';
import 'package:quax/tweet/stale_feed_preview.dart';
import 'package:quax/tweet/tweet_skeleton.dart';
import 'package:quax/ui/caught_up_divider.dart';
import 'package:quax/ui/caught_up_end_card.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/stale_feed_banner.dart';
import 'package:quax/utils/paging.dart';

typedef TweetPageResult = ({List<TweetChain> chains, String? nextCursor});
typedef TweetPageLoader = Future<TweetPageResult> Function(String? cursor);

/// Why pagination stopped short of the end of the feed. Both stops are the
/// same mechanism: hold the cursor back, show a card, resume on request.
enum FeedPause {
  /// Zen mode's per-session page cap.
  pageCap,

  /// Catch-up mode reached the reader's last read position.
  caughtUp,
}

/// Owns a [CursorPagingController] for cursor-paginated tweet chains, bridging
/// it onto the app's `(chains, nextCursor)` loaders.
///
/// v5 bakes the fetch callback into the controller at construction, yet several
/// feeds create the controller away from the loader (and cache it across widget
/// remounts — see [FeedSessionCache]). So the loader lives in a rebindable field
/// that [PaginatedTweetList] sets on mount.
class TweetFeedController {
  late final CursorPagingController<String, TweetChain> _paging;
  TweetPageLoader? _loader;

  /// When set, pagination pauses after this many pages per session instead of
  /// scrolling forever (`null` result → no cap). Feeds bind this to the
  /// zen-mode preference; search and quotes leave it unset.
  int? Function()? pageCapProvider;

  /// The "already read" predicate while catch-up mode is on for this feed, or
  /// `null` when it is off. Pagination then stops at the first chain the
  /// predicate accepts, which makes the feed finishable.
  SeenChainPredicate? Function()? catchUpPredicateProvider;

  int _pagesFetched = 0;
  FeedPause? _pausedBy;
  // The real next cursor stashed when a stop paused pagination, so "load more"
  // can resume where the feed stopped.
  String? _pausedCursor;
  // Chains cut off the paused page. They were fetched, so they are handed back
  // on resume rather than re-requested.
  List<TweetChain> _heldBack = const [];
  // Set once the reader has chosen to read past their last position, so the
  // catch-up stop applies once per first page rather than on every page.
  bool _catchUpPassed = false;

  TweetFeedController() {
    _paging = CursorPagingController<String, TweetChain>(_fetch);
  }

  PagingController<int, TweetChain> get controller => _paging.pagingController;

  set loader(TweetPageLoader loader) => _loader = loader;

  bool get hasItems => _paging.items != null;

  /// The chains loaded so far, or `null` before the first page.
  List<TweetChain>? get items => _paging.items;

  FeedPause? get pauseReason => _pausedBy;

  /// Whether there is anything left to show past the pause. A feed that stopped
  /// on the last page of results has nothing, and must not offer more.
  bool get canContinuePastPause => _pausedCursor != null || _heldBack.isNotEmpty;

  /// Resumes pagination past whichever stop paused it: the held-back chains go
  /// on screen first, then paging continues from the stashed cursor.
  void continuePastPause() {
    final reason = _pausedBy;
    if (reason == null) {
      return;
    }
    final cursor = _pausedCursor;
    final held = _heldBack;
    _pausedBy = null;
    _pausedCursor = null;
    _heldBack = const [];
    _pagesFetched = 0;
    _catchUpPassed = _catchUpPassed || reason == FeedPause.caughtUp;
    if (held.isNotEmpty) {
      _paging.resumeWith(held, cursor);
    } else if (cursor != null) {
      _paging.resume(cursor);
    }
  }

  /// Applies the stops that make a feed finite, in order of authority: the
  /// reader's own position first, then the zen-mode page cap.
  CursorPage<String, TweetChain> _applyStops(List<TweetChain> items, String? next) {
    _pausedBy = null;
    _pausedCursor = null;
    _heldBack = const [];

    final isSeen = _catchUpPassed ? null : catchUpPredicateProvider?.call();
    if (isSeen != null) {
      final split = splitAtFirstSeen(items, isSeen);
      if (split.reachedBoundary) {
        _pausedBy = FeedPause.caughtUp;
        _pausedCursor = next;
        _heldBack = split.held;
        return (items: split.keep, nextCursor: null);
      }
    }

    return (items: items, nextCursor: _applyPageCap(next));
  }

  String? _applyPageCap(String? next) {
    final cap = pageCapProvider?.call();
    if (next == null || cap == null || _pagesFetched < cap) {
      return next;
    }
    _pausedBy = FeedPause.pageCap;
    _pausedCursor = next;
    return null;
  }

  Future<CursorPage<String, TweetChain>> _fetch(String? cursor) async {
    final result = await _loader!(cursor);
    final next = result.nextCursor;
    // Later pages can overlap earlier ones (search cursors aren't exact
    // boundaries), so drop chains that are already displayed. Last-page
    // detection stays on the unfiltered page: an all-duplicates page still
    // carries a cursor worth following.
    final seen = cursor == null ? <String>{} : (_paging.items ?? const <TweetChain>[]).map((e) => e.id).toSet();
    final items = result.chains.where((c) => seen.add(c.id)).toList();
    if (cursor == null) {
      _pagesFetched = 0;
      _catchUpPassed = false;
    }
    _pagesFetched++;
    final naturalNext = _isLastPage(result.chains, next, cursor) ? null : next;
    return _applyStops(items, naturalNext);
  }

  // Pagination ends on an empty page, a missing/blank cursor, or a cursor that
  // didn't advance (which would otherwise loop forever).
  bool _isLastPage(List<TweetChain> chains, String? next, String? cursor) =>
      chains.isEmpty || next == null || next.isEmpty || next == cursor;

  /// Reloads the first page and replaces the items in place, *without* resetting
  /// to the first-page spinner the way [PagingController.refresh] does. Used by
  /// pull-to-refresh so the existing tweets stay visible under the indicator.
  Future<void> softRefresh() async {
    try {
      final result = await _loader!(null);
      final next = result.nextCursor;
      final isLast = _isLastPage(result.chains, next, null);
      _pagesFetched = 1;
      _catchUpPassed = false;
      final page = _applyStops(result.chains, isLast ? null : next);
      _paging.replaceFirstPage(page.items, page.nextCursor);
    } catch (e, stackTrace) {
      _paging.setError(e, stackTrace);
    }
  }

  void dispose() => _paging.dispose();
}

/// Shared paginated tweet list used by the For-you feed, the group feed and
/// the tweet search results. Drives a [TweetFeedController]'s v5 controller
/// through the standard `PagedListView` shell with error / empty widgets.
///
/// The controller's lifecycle (creation, disposal, cross-mount caching) stays
/// at the call site — this widget only binds the loader and, while a cached
/// preview is shown, kicks off the first page itself.
class PaginatedTweetList extends StatefulWidget {
  final TweetFeedController feed;
  final TweetPageLoader loadPage;
  final String? username;
  final Future<void> Function()? onRefresh;
  final String firstPageErrorPrefix;
  final String newPageErrorPrefix;
  final String emptyMessage;
  // Cached tweets shown in place of the first-page spinner while the initial
  // load is in flight, so a feed reveals its cached content instead of a
  // full-screen progress indicator. They are also what the feed falls back to
  // when the first page fails outright.
  final List<TweetChain>? firstPagePreview;
  // When the cached tweets were saved. Shown on the stale banner: "these posts
  // are from 14:05" is the difference between a feed that looks broken and one
  // the reader can judge for themselves.
  final DateTime? firstPagePreviewCachedAt;
  // Reports that the reader reached the end of what was new in catch-up mode —
  // the one moment at which moving their read position is deliberate.
  final VoidCallback? onCaughtUp;
  // Whether the load could not fetch everything between the newest posts and
  // the reader's last position (the gap-fill cap), so the completion card must
  // not claim the feed is finished. Read when the card builds, not when the
  // widget is created.
  final bool Function()? catchUpMayBeIncomplete;
  // Reading-position support: when set, a "You're caught up" divider is drawn
  // above the first chain this predicate marks as already seen. The predicate
  // must stay frozen for the mount so the divider doesn't move mid-session.
  final bool Function(TweetChain chain)? isSeen;
  final Key? caughtUpDividerKey;

  /// Posts from somewhere other than X, slotted among the chains by date.
  final List<InterleavedItem> interleaved;

  const PaginatedTweetList({
    super.key,
    required this.feed,
    required this.loadPage,
    required this.username,
    required this.firstPageErrorPrefix,
    required this.newPageErrorPrefix,
    required this.emptyMessage,
    this.onRefresh,
    this.firstPagePreview,
    this.firstPagePreviewCachedAt,
    this.onCaughtUp,
    this.catchUpMayBeIncomplete,
    this.isSeen,
    this.caughtUpDividerKey,
    this.interleaved = const [],
  });

  @override
  State<PaginatedTweetList> createState() => _PaginatedTweetListState();
}

class _PaginatedTweetListState extends State<PaginatedTweetList> {
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  FeedRefreshController? _refreshController;
  bool _firstLoadStarted = false;
  bool _pendingInitialLoad = false;
  // Local to the view: dismissing the stale banner hides the explanation, never
  // the cached posts under it.
  bool _staleBannerDismissed = false;

  PagingController<int, TweetChain> get _controller => widget.feed.controller;

  @override
  void initState() {
    super.initState();
    widget.feed.loader = widget.loadPage;
    // While we show the cached preview the PagedListView isn't mounted, so it
    // can't trigger the first page itself — we rebuild to swap it in once items
    // arrive, so listen for that.
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only feeds that support pull-to-refresh expose their refresh to the
    // app-bar button. Outside a GroupFeedShell there is no controller to bind.
    if (widget.onRefresh == null) return;
    FeedRefreshController? controller;
    try {
      controller = context.read<FeedRefreshController>();
    } on ProviderNotFoundException {
      controller = null;
    }
    if (!identical(controller, _refreshController)) {
      _refreshController?.unregister(_showRefresh);
      _refreshController = controller;
      _refreshController?.register(_showRefresh);
    }
  }

  @override
  void didUpdateWidget(PaginatedTweetList oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.feed.loader = widget.loadPage;
    if (!identical(oldWidget.feed, widget.feed)) {
      oldWidget.feed.controller.removeListener(_onControllerChanged);
      _controller.addListener(_onControllerChanged);
      // A fresh feed may need its first page kicked off again from the preview.
      _firstLoadStarted = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _refreshController?.unregister(_showRefresh);
    super.dispose();
  }

  void _onControllerChanged() {
    // PagingListener already rebuilds the list on controller changes; this
    // extra rebuild only matters for swapping the cached preview out once the
    // first page arrives, so skip it entirely when there is no preview.
    if (mounted && widget.firstPagePreview != null) setState(() {});
  }

  // Drives the same RefreshIndicator the user pulls down, so the app-bar refresh
  // button shows the top spinner and runs the soft refresh identically.
  Future<void> _showRefresh() async {
    await _refreshKey.currentState?.show();
  }

  // Keyed by chain id: a soft refresh replaces the first page in place, and
  // without a key Flutter would reuse each element positionally and leave the
  // tile below it rendering the post that used to sit there.
  Widget _buildChain(BuildContext context, TweetChain chain) => TweetConversation(
      key: ValueKey(chain.id),
      id: chain.id,
      tweets: chain.tweets,
      username: widget.username,
      isPinned: chain.isPinned);

  /// Soft refresh used by the pull-to-refresh gesture. Runs the caller's
  /// [onRefresh] side effects, then reloads the first page while keeping the
  /// current tweets visible (the RefreshIndicator shows its own small spinner on
  /// top). Awaited so the spinner stays until done.
  Future<void> _handleRefresh() async {
    await widget.onRefresh?.call();
    if (!mounted) return;
    await widget.feed.softRefresh();
  }

  // True while we should display the cached preview: the first page hasn't
  // loaded yet, there's no error to surface, and we actually have cached tweets.
  bool get _showingPreview {
    final preview = widget.firstPagePreview;
    final state = _controller.value;
    return preview != null && preview.isNotEmpty && state.items == null && state.error == null;
  }

  /// The cached posts under an explanation, when the first page failed and
  /// there is something cached to fall back on.
  ///
  /// The error is not swallowed: a reader whose accounts are all rate-limited
  /// has to know why nothing new arrived, and that these posts are old. It is
  /// moved out of the way of a feed that could perfectly well be read.
  Widget? _buildStaleView() {
    final state = _controller.value;
    final preview = widget.firstPagePreview;
    if (!shouldShowStalePreview(error: state.error, items: state.items, preview: preview)) {
      return null;
    }

    final list = CachedTweetList(preview!, username: widget.username);
    if (_staleBannerDismissed) {
      return list;
    }

    return Column(
      children: [
        StaleFeedBanner(
          reason: staleFeedReasonOf(pagingErrorOf(state)?.error ?? state.error),
          cachedAt: widget.firstPagePreviewCachedAt,
          onRetry: _retryFirstPage,
          onDismiss: () => setState(() => _staleBannerDismissed = true),
        ),
        Expanded(child: list),
      ],
    );
  }

  void _retryFirstPage() {
    setState(() => _staleBannerDismissed = false);
    _controller.fetchNextPage();
  }

  /// The card that closes a feed which stopped on purpose, or null when
  /// pagination simply ran out.
  Widget? _buildEndCard(List<TweetChain> loaded) {
    final reason = widget.feed.pauseReason;
    if (reason == FeedPause.caughtUp) {
      return CaughtUpEndCard(
        mayBeIncomplete: widget.catchUpMayBeIncomplete?.call() ?? false,
        nothingNew: loaded.isEmpty,
        onShowOlder: widget.feed.canContinuePastPause ? widget.feed.continuePastPause : null,
        onReached: widget.onCaughtUp,
      );
    }
    if (reason == FeedPause.pageCap) {
      return _ZenFeedEndCard(onLoadMore: widget.feed.continuePastPause);
    }
    return null;
  }

  // A group can hold nothing but subreddits or publications, and a catch-up
  // feed with nothing new holds no chains at all. Neither is "no posts", so the
  // empty message is the last resort rather than the first.
  Widget _buildEmpty(BuildContext context, List<InterleavedItem> items, Widget? endCard) {
    if (items.isEmpty && endCard == null) {
      return Center(child: Text(widget.emptyMessage));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) item.build(context),
        if (endCard != null) endCard,
      ],
    );
  }

  // The PagedListView normally kicks off the first page when it mounts. While
  // the preview replaces it, nothing does — so trigger the load ourselves once.
  void _maybeStartFirstLoad() {
    if (_firstLoadStarted) return;
    final state = _controller.value;
    if (state.items != null || state.error != null) return;
    _firstLoadStarted = true;
    // Deferred: we're called from build() and fetchNextPage() mutates the
    // controller synchronously, which would setState() mid-build via our listener.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.onRefresh == null) {
        _controller.fetchNextPage();
        return;
      }
      final refreshState = _refreshKey.currentState;
      if (refreshState != null) {
        _pendingInitialLoad = true;
        refreshState.show();
      } else {
        _controller.fetchNextPage();
      }
    });
  }

  Future<void> _onRefreshTriggered() async {
    if (_pendingInitialLoad) {
      _pendingInitialLoad = false;
      await widget.feed.softRefresh();
      return;
    }
    await _handleRefresh();
  }

  Widget _wrapWithRefresh(Widget child) {
    if (widget.onRefresh == null) return child;
    return RefreshIndicator(key: _refreshKey, onRefresh: _onRefreshTriggered, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (_showingPreview) {
      _maybeStartFirstLoad();
      return _wrapWithRefresh(CachedTweetList(widget.firstPagePreview!, username: widget.username));
    }

    final stale = _buildStaleView();
    if (stale != null) {
      return _wrapWithRefresh(stale);
    }

    final list = PagingListener<int, TweetChain>(
      controller: _controller,
      builder: (context, state, fetchNextPage) {
        // Recomputed per build from the loaded items, so the boundary shows
        // up even when the first seen chain only arrives on a later page.
        final seen = widget.isSeen;
        final loaded = state.items ?? const <TweetChain>[];
        final boundary = seen == null ? null : _caughtUpBoundaryOf(loaded, seen);
        final buckets = placeInterleaved(loaded, widget.interleaved);
        final endCard = _buildEndCard(loaded);
        return PagedListView<int, TweetChain>(
          padding: EdgeInsets.only(top: 4, bottom: MediaQuery.of(context).padding.bottom),
          state: state,
          fetchNextPage: fetchNextPage,
          addAutomaticKeepAlives: false,
          builderDelegate: PagedChildBuilderDelegate(
            itemBuilder: (context, chain, index) {
              final conversation = _buildChain(context, chain);
              final above = index < buckets.length ? buckets[index] : const <InterleavedItem>[];
              // Anything older than every chain loaded so far rides along with
              // the last one, so it is on screen rather than waiting for a page
              // that may never be asked for.
              final below = index == loaded.length - 1 ? buckets.last : const <InterleavedItem>[];
              final showsDivider = boundary != null && index == boundary;

              if (above.isEmpty && below.isEmpty && !showsDivider) {
                return conversation;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showsDivider) CaughtUpDivider(key: widget.caughtUpDividerKey),
                  for (final item in above) item.build(context),
                  conversation,
                  for (final item in below) item.build(context),
                ],
              );
            },
            firstPageProgressIndicatorBuilder: (context) => const TweetFeedSkeleton(),
            newPageProgressIndicatorBuilder: (context) => const TweetSkeletonTile(),
            firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: pagingErrorOf(state)?.error,
              stackTrace: pagingErrorOf(state)?.stackTrace,
              prefix: widget.firstPageErrorPrefix,
              onRetry: fetchNextPage,
            ),
            newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: pagingErrorOf(state)?.error,
              stackTrace: pagingErrorOf(state)?.stackTrace,
              prefix: widget.newPageErrorPrefix,
              onRetry: fetchNextPage,
            ),
            noItemsFoundIndicatorBuilder: (context) => _buildEmpty(context, buckets.last, endCard),
            noMoreItemsIndicatorBuilder: (context) => endCard ?? const SizedBox.shrink(),
          ),
        );
      },
    );

    return _wrapWithRefresh(list);
  }

  // Index of the first already-seen chain, when at least one new chain sits
  // above it. Index 0 means nothing is new; no boundary yet means the seen
  // chains haven't been loaded — both draw no divider.
  static int? _caughtUpBoundaryOf(List<TweetChain> chains, bool Function(TweetChain) isSeen) {
    final index = chains.indexWhere(isSeen);
    return index <= 0 ? null : index;
  }
}

/// Calm end-of-feed card shown when the zen-mode page cap paused pagination,
/// offering a deliberate way to keep reading instead of an infinite scroll.
class _ZenFeedEndCard extends StatelessWidget {
  final VoidCallback onLoadMore;

  const _ZenFeedEndCard({required this.onLoadMore});

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.self_improvement, size: 36, color: hintColor),
          const SizedBox(height: 12),
          Text(
            L10n.of(context).zen_mode_feed_end,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: hintColor),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onLoadMore, child: Text(L10n.of(context).zen_mode_load_more)),
        ],
      ),
    );
  }
}
