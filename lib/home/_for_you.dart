import 'package:flutter/material.dart';
import 'package:xta/client/client.dart';
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

  @override
  void initState() {
    super.initState();
    widget.feed.pageCapProvider = _zenPageCap;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRedditPosts());
  }

  Future<void> _loadRedditPosts() async {
    final items = await loadRedditInterleaved(context, redditHomeSubreddits(context));
    if (mounted && items.isNotEmpty) {
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
    return (chains: result.chains, nextCursor: result.cursorBottom);
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

            return PaginatedTweetList(
              feed: widget.feed,
              loadPage: _loadTweets,
              interleaved: _redditItems,
              username: user.screenName,
              onRefresh: () async {},
              firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets,
              newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
              emptyMessage: L10n.of(context).unable_to_load_the_tweets_for_the_feed,
            );
          });
        });
  }
}
