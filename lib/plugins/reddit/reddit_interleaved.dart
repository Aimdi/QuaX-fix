import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/ui/provenance_accent.dart';
import 'package:xta/plugins/reddit/reddit_auth.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_post_card.dart';
import 'package:xta/plugins/reddit/reddit_read_session.dart';
import 'package:xta/plugins/reddit/reddit_sort_sheet.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';
import 'package:xta/tweet/interleaved_items.dart';

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
  RedditAuth? auth,
}) async {
  if (subreddits.isEmpty) {
    return const [];
  }

  final client = context.read<RedditClient>();
  final prefs = PrefService.of(context, listen: false);
  final sort = storedRedditSort(prefs);
  final session = await RedditReadSession.resolve(prefs: prefs, auth: auth);

  // Fetched together rather than one after another: a group with six
  // subreddits paid six round trips end to end, and the feed waited on the sum.
  final listings = await Future.wait(subreddits.map((name) async {
    try {
      return await session.fetchSubreddit(client, name, sort: sort, limit: limit);
    } catch (e) {
      _log.warning('Unable to load r/$name: $e');
      return null;
    }
  }));

  final items = <InterleavedItem>[];
  for (final listing in listings.nonNulls) {
    for (final post in listing.posts.where((p) => !p.stickied)) {
      final date = post.createdAt;
      if (date == null) {
        continue;
      }
      items.add(provenanceInterleavedItem(
        date: date,
        pluginId: pluginIdReddit,
        build: (_) => RedditPostCard(post: post),
      ));
    }
  }

  return items;
}
