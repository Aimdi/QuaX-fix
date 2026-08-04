import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/_for_you.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/_feed_shell.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/plugins/reddit/reddit_feed_list.dart';

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
  final TweetFeedController _feedController = TweetFeedController();
  FeedTab? _tab;

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
        final model = context.read<GroupModel>();
        return defaultGroupActions(
          context,
          model: model,
          showMore: tab == FeedTab.following,
        );
      },
      bodyBuilder: (context) => switch (tab) {
        // With a cache key this feed survives a trip to another tab, the way a
        // pushed group route already does. Without one, every Following → For
        // you → Following swipe rebuilt the whole per-chunk fan-out.
        FeedTab.following => SubscriptionGroupScreenContent(id: widget.id, cacheKey: widget.id),
        FeedTab.reddit => RedditFeedList(scrollController: widget.scrollController),
        FeedTab.foryou => ForYouTweets(_feedController, type: 'profile', includeReplies: false, pref: prefs),
      },
    );
  }
}
