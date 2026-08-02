import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/home/_account_avatar.dart';
import 'package:xta/home/_for_you.dart';
import 'package:xta/tweet/paginated_tweet_list.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/group/_feed_shell.dart';
import 'package:xta/group/feed_refresh_controller.dart';
import 'package:xta/group/group_model.dart';
import 'package:xta/group/group_screen.dart';
import 'package:xta/plugins/reddit/reddit_actions.dart';
import 'package:xta/plugins/reddit/reddit_feed_list.dart';
import 'package:xta/ui/scroll_to_top.dart';

typedef FeedTabTitleBuilder = String Function(BuildContext context);

enum FeedTab { following, foryou, reddit }

class FeedTabOption {
  final FeedTab id;
  final FeedTabTitleBuilder titleBuilder;

  FeedTabOption(this.id, this.titleBuilder);
}

final List<FeedTabOption> feedTabs = [
  FeedTabOption(FeedTab.following, (c) => L10n.of(c).following),
  FeedTabOption(FeedTab.foryou, (c) => L10n.of(c).foryou),
  FeedTabOption(FeedTab.reddit, (c) => L10n.of(c).plugin_reddit_title),
];

/// The feeds the switcher currently offers.
///
/// Reddit is one of them only while its plugin is on — an entry that led to an
/// empty screen would be worse than no entry, and the choice is stored by name
/// so turning the plugin off simply stops offering it.
List<FeedTabOption> availableFeedTabs(BasePrefService prefs) => feedTabs
    .where((e) => e.id != FeedTab.reddit || prefs.get<bool>(optionPluginRedditEnabled) == true)
    .toList(growable: false);

FeedTab feedTabFromId(String? id) =>
    FeedTab.values.firstWhere((e) => e.name == id, orElse: () => FeedTab.following);

class FeedScreen extends StatefulWidget {
  final ScrollController scrollController;
  final String id;
  final String name;

  const FeedScreen({super.key, required this.scrollController, required this.id, required this.name});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  TweetFeedController _forYouFeed = TweetFeedController();
  FeedTab? _tab;
  // Bumped on For-you refresh so the tab remounts with a fresh controller —
  // softRefresh alone left mid-scroll users looking at stale tiles until they
  // switched tabs (#168).
  int _forYouEpoch = 0;

  @override
  void dispose() {
    _forYouFeed.dispose();
    super.dispose();
  }

  Future<void> _refreshActiveTab(FeedTab tab) async {
    await scrollToTop(context, widget.scrollController);
    if (!mounted) {
      return;
    }

    if (tab == FeedTab.foryou) {
      final previous = _forYouFeed;
      setState(() {
        _forYouFeed = TweetFeedController();
        _forYouEpoch++;
      });
      // Dispose after the remount so the outgoing ForYouTweets isn't holding a
      // dead controller for the rest of this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      return;
    }

    await context.read<FeedRefreshController>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final BasePrefService prefs = PrefService.of(context);
    final available = availableFeedTabs(prefs);
    var tab = _tab ??= feedTabFromId(prefs.get<String>(optionHomeDefaultFeedTab));
    // The plugin can be turned off while its feed is the one being shown.
    if (!available.any((e) => e.id == tab)) {
      tab = _tab = FeedTab.following;
    }

    // The feeds are X-style tabs under the title, not a form-field dropdown in
    // it. Keyed by how many there are so toggling the Reddit plugin rebuilds
    // the controller instead of leaving it one tab short.
    return DefaultTabController(
      key: ValueKey(available.length),
      length: available.length,
      initialIndex: max(0, available.indexWhere((e) => e.id == tab)),
      child: GroupFeedShell(
        scrollController: widget.scrollController,
        groupId: widget.id,
        centerTitle: true,
        leading: const DrawerAvatarButton(),
        titleBuilder: (context) => Text(L10n.of(context).fritter),
        bottomBuilder: (context) => TabBar(
          // The shell draws the bar's hairline; the TabBar's own divider on top
          // of it would double the line.
          dividerHeight: 0,
          tabs: available.map((e) => Tab(text: e.titleBuilder(context))).toList(),
          onTap: (index) => setState(() => _tab = available[index].id),
        ),
        actionsBuilder: (context) {
          // Reddit brings its own bar: sorting, search and adding a subreddit
          // are what this feed is steered with, and the generic feed actions
          // steer nothing here. Its overflow carries the app settings so they
          // stay reachable from this tab too.
          if (tab == FeedTab.reddit) {
            return const [RedditFeedActions(showAppSettings: true)];
          }

          // Only the feed filters. Refresh is the pull gesture and settings
          // live in the drawer — except on For you, whose pull gesture cannot
          // rebuild the timeline, so it keeps the explicit refresh (#168).
          final model = context.read<GroupModel>();
          return defaultGroupActions(
            context,
            model: model,
            showMore: tab == FeedTab.following,
            showRefresh: tab == FeedTab.foryou,
            onRefresh: () => _refreshActiveTab(tab),
            showSettings: false,
          );
        },
        bodyBuilder: (context) => switch (tab) {
          FeedTab.following => SubscriptionGroupScreenContent(id: widget.id),
          FeedTab.reddit => RedditFeedList(scrollController: widget.scrollController),
          FeedTab.foryou => ForYouTweets(
                _forYouFeed,
                key: ValueKey(_forYouEpoch),
                type: 'profile',
                includeReplies: false,
                pref: prefs,
              ),
        },
      ),
    );
  }
}
