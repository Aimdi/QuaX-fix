import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/group/_settings.dart';
import 'package:xta/group/feed_refresh_controller.dart';
import 'package:xta/group/combined_groups.dart';
import 'package:xta/group/group_model.dart';
import 'package:xta/subscriptions/users_model.dart';
import 'package:xta/tweet/tweet_chrome.dart';
import 'package:xta/ui/scroll_to_top.dart';
import 'package:xta/group/feed_rules.dart';

class GroupFeedShell extends StatefulWidget {
  final ScrollController scrollController;
  final String groupId;
  final WidgetBuilder titleBuilder;
  final WidgetBuilder bodyBuilder;
  final List<Widget> Function(BuildContext) actionsBuilder;

  /// An extra strip under the title row — the home screen puts its feed tabs
  /// here. The shell finishes the bar with a hairline either way, so content
  /// scrolling underneath no longer dissolves into it.
  final PreferredSizeWidget Function(BuildContext)? bottomBuilder;

  /// X centres its logo; group names stay leading like every pushed screen.
  final bool centerTitle;

  /// The app bar's leading slot. The home feed puts the account avatar here (it
  /// opens the drawer, as X's does); a pushed group leaves it null for the
  /// default back button.
  final Widget? leading;
  // Whether the body's feed keeps its PagingController in the FeedSessionCache.
  // Only then does a subscription change require remounting the body (to drop
  // the just-invalidated cached controller); other feeds refresh on their own
  // when their group state actually changes.
  final bool usesFeedCache;

  const GroupFeedShell({
    super.key,
    required this.scrollController,
    required this.groupId,
    required this.titleBuilder,
    required this.bodyBuilder,
    required this.actionsBuilder,
    this.bottomBuilder,
    this.centerTitle = false,
    this.leading,
    this.usesFeedCache = false,
  });

  @override
  State<GroupFeedShell> createState() => _GroupFeedShellState();
}

class _GroupFeedShellState extends State<GroupFeedShell> with AutomaticKeepAliveClientMixin<GroupFeedShell> {
  late GroupModel _groupModel;
  final FeedRefreshController _feedRefreshController = FeedRefreshController();
  int _refreshCounter = 0;
  // Cached refs captured in didChangeDependencies — accessing the InheritedWidget
  // tree via context.read in dispose() triggers a framework warning, since
  // ancestors may already be unmounted by then.
  SubscriptionsModel? _subscriptionsModel;
  GroupsModel? _groupsModel;

  late final String _callbackKey = 'GroupFeedShell-${widget.groupId}-${identityHashCode(this)}';

  @override
  bool get wantKeepAlive => true;

  CombinedGroupsStore? _combined;
  Set<String> _alsoRead = const {};

  @override
  void initState() {
    super.initState();
    _groupModel = GroupModel(widget.groupId)..loadGroup();
  }

  /// Rebuilds the feed over the groups now being read together.
  ///
  /// A new model rather than a reload: which groups the membership queries ask
  /// about is fixed when the model is made, and the feed below keys off the
  /// members it returns.
  void _onCombinationChanged() {
    final combined = _combined;
    if (!mounted || combined == null) {
      return;
    }

    final next = combined.state.where((e) => e != widget.groupId).toSet();
    if (setEquals(next, _alsoRead)) {
      return;
    }

    setState(() {
      _alsoRead = next;
      _groupModel = GroupModel(widget.groupId, alsoRead: next)..loadGroup();
      _refreshCounter++;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSubs = context.read<SubscriptionsModel>();
    final newGroups = context.read<GroupsModel>();
    if (!identical(newSubs, _subscriptionsModel) || !identical(newGroups, _groupsModel)) {
      _subscriptionsModel?.removeReloadListener(_callbackKey);
      _groupsModel?.removeReloadListener(_callbackKey);
      _subscriptionsModel = newSubs;
      _groupsModel = newGroups;
      _subscriptionsModel!.addReloadListener(_callbackKey, _onReload);
      _groupsModel!.addReloadListener(_callbackKey, _onReload);
    }

    // Picking another group to read alongside this one rebuilds the feed over
    // both, without either group being changed.
    final combined = context.read<CombinedGroupsStore>();
    if (!identical(combined, _combined)) {
      _combined = combined;
      combined.observer(onState: (_) => _onCombinationChanged());
      _onCombinationChanged();
    }
  }

  // What the feed actually shows; a reload only warrants remounting the body
  // when this changes, otherwise following someone unrelated would needlessly
  // reload the open timeline.
  String _fingerprint(SubscriptionGroupGet group) {
    // Sorted, because what the feed shows is the *set* of members and not the
    // order a query happened to return them in. Hashing them unsorted is why
    // adding someone to a group made the timeline reset over and over: the
    // membership queries have no ORDER BY, so SQLite is free to hand back the
    // same members in a different order once the table has changed under it,
    // and every later reload then looked like a different group.
    final members = (group.subscriptions.map((s) => '${s.id}:${s.inFeed}').toList()..sort()).join(',');
    return '$members|${group.includeReplies}|${group.includeRetweets}|${group.popular}|${group.custom}|${feedRulesOf(group).cacheKey}';
  }

  // Triggered when subscriptions or group memberships change. A single user
  // action can fire this several times in a row (subscriptions and groups both
  // reload), so the reaction is debounced into one refresh. The body is only
  // remounted for cache-backed feeds whose content actually changed; everything
  // else just reloads its group state and the feed decides on its own.
  void _onReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 150), () async {
      if (!mounted) return;
      final before = _fingerprint(_groupModel.state);
      await _groupModel.loadGroup();
      if (!mounted) return;
      setState(() {
        if (widget.usesFeedCache && _fingerprint(_groupModel.state) != before) {
          _refreshCounter++;
        }
      });
    });
  }

  Timer? _reloadDebounce;

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _subscriptionsModel?.removeReloadListener(_callbackKey);
    _groupsModel?.removeReloadListener(_callbackKey);
    super.dispose();
  }

  PreferredSizeWidget _bottom(BuildContext context) {
    final inner = widget.bottomBuilder?.call(context);
    return PreferredSize(
      preferredSize: Size.fromHeight((inner?.preferredSize.height ?? 0) + kTweetDividerThickness),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inner != null) inner,
          tweetHairlineDivider(context),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Provider<GroupModel>.value(
      value: _groupModel,
      builder: (context, child) {
        return Provider<FeedRefreshController>.value(
          value: _feedRefreshController,
          child: NestedScrollView(
            controller: widget.scrollController,
            floatHeaderSlivers: true,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  pinned: false,
                  snap: true,
                  floating: true,
                  centerTitle: widget.centerTitle,
                  leading: widget.leading,
                  title: widget.titleBuilder(context),
                  actions: widget.actionsBuilder(context),
                  bottom: _bottom(context),
                ),
              ];
            },
            body: KeyedSubtree(
              key: ValueKey(_refreshCounter),
              child: widget.bodyBuilder(context),
            ),
          ),
        );
      },
    );
  }
}

/// Builds the standard action-bar icons shared by group feeds:
/// optional "more" (group settings), optional "scroll-to-top", refresh, and
/// the global settings button.
List<Widget> defaultGroupActions(
  BuildContext context, {
  required GroupModel model,
  ScrollController? scrollToTopController,
  bool showMore = true,
  bool showRefresh = true,
  bool showSettings = true,
  VoidCallback? onRefresh,
  List<Widget> extra = const [],
}) {
  return [
    if (showMore)
      IconButton(icon: const Icon(Icons.build_outlined), onPressed: () => showFeedSettings(context, model)),
    if (scrollToTopController != null)
      IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: () async => await scrollToTop(context, scrollToTopController)),
    if (showRefresh)
      IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh ?? () async => await context.read<FeedRefreshController>().refresh()),
    if (showSettings)
      IconButton(
          icon: const Icon(Icons.settings), onPressed: () => Navigator.pushNamed(context, routeSettings)),
    ...extra,
  ];
}
