import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
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

    return GroupFeedShell(
      scrollController: widget.scrollController,
      groupId: widget.id,
      titleBuilder: (context) => DropdownMenu<FeedTab>(
        initialSelection: tab,
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
        dropdownMenuEntries:
            available.map((e) => DropdownMenuEntry(value: e.id, label: e.titleBuilder(context))).toList(),
        onSelected: (value) {
          setState(() => _tab = value!);
        },
      ),
      actionsBuilder: (context) {
        // Reddit brings its own bar: sorting, search and adding a subreddit are
        // what this feed is steered with, and the generic feed actions steer
        // nothing here. Its overflow carries the app settings so the one thing
        // the shell would have contributed is not lost.
        if (tab == FeedTab.reddit) {
          return const [RedditFeedActions(showAppSettings: true)];
        }

        final model = context.read<GroupModel>();
        return defaultGroupActions(
          context,
          model: model,
          showMore: tab == FeedTab.following,
          onRefresh: () => _refreshActiveTab(tab),
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
    );
  }
}
