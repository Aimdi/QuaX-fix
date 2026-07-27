import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';
import 'package:quax/plugins/reddit/reddit_post_card.dart';
import 'package:quax/plugins/reddit/reddit_sort_sheet.dart';
import 'package:quax/plugins/reddit/reddit_store.dart';
import 'package:quax/tweet/interleaved_items.dart';

final _log = Logger('RedditInterleaved');

/// How many posts each subreddit contributes to a shared timeline.
///
/// Small on purpose: the X side pages on and on, and a subreddit that dropped
/// twenty-five posts in would own the top of the feed rather than joining it.
const int kRedditInterleavedPageSize = 10;

/// Whether followed subreddits belong in the home timeline. Off unless asked
/// for: a reader who turned the plugin on wanted a Reddit tab, not a different
/// Following feed.
bool redditInHomeFeed(BasePrefService prefs) =>
    prefs.get<bool>(optionPluginRedditEnabled) == true && prefs.get<bool>(optionPluginRedditInHomeFeed) == true;

/// The subreddits the home timeline should mix in — none unless the option is
/// on.
List<String> redditHomeSubreddits(BuildContext context) {
  final prefs = PrefService.of(context, listen: false);
  if (!redditInHomeFeed(prefs)) {
    return const [];
  }

  return context.read<RedditSubredditsStore>().state;
}

/// One page of each subreddit, as dated items a tweet list can slot between its
/// chains.
///
/// One unreachable subreddit must not empty the timeline of the others, so each
/// is caught on its own. A post with no date is dropped rather than guessed at:
/// there is nowhere in a chronological feed to put it.
Future<List<InterleavedItem>> loadRedditInterleaved(
  BuildContext context,
  List<String> subreddits, {
  int limit = kRedditInterleavedPageSize,
}) async {
  if (subreddits.isEmpty) {
    return const [];
  }

  final client = context.read<RedditClient>();
  final prefs = PrefService.of(context, listen: false);
  final clientId = prefs.get<String>(optionPluginRedditClientId) ?? '';
  final preferPublic = prefs.get<String>(optionPluginRedditSource) == redditSourcePublic;
  final sort = storedRedditSort(prefs);

  final items = <InterleavedItem>[];
  for (final name in subreddits) {
    try {
      final listing = await client.fetchSubreddit(name,
          clientId: clientId, sort: sort, limit: limit, preferPublic: preferPublic);

      for (final post in listing.posts.where((p) => !p.stickied)) {
        final date = post.createdAt;
        if (date == null) {
          continue;
        }
        items.add((date: date, build: (context) => RedditPostCard(post: post)));
      }
    } catch (e) {
      _log.warning('Unable to load r/$name: $e');
    }
  }

  return items;
}
