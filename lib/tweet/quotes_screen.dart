import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/tweet_context_scope.dart';

class QuotesScreenArguments {
  final String id;

  QuotesScreenArguments({required this.id});

  @override
  String toString() {
    return 'QuotesScreenArguments{id: $id}';
  }
}

/// Lists the posts quoting a given tweet, via the `quoted_tweet_id:` search
/// operator.
class QuotesScreen extends StatelessWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as QuotesScreenArguments;
    return _QuotesScreen(id: args.id);
  }
}

class _QuotesScreen extends StatefulWidget {
  final String id;

  const _QuotesScreen({required this.id});

  @override
  State<_QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<_QuotesScreen> {
  final TweetFeedController _feed = TweetFeedController();

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  Future<TweetPageResult> _loadPage(String? cursor) async {
    final result = await Twitter.searchTweets('quoted_tweet_id:${widget.id}', true, cursor: cursor);
    return (chains: result.chains, nextCursor: result.cursorBottom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).quotes)),
      body: TweetContextScope(
        child: PaginatedTweetList(
          feed: _feed,
          loadPage: _loadPage,
          username: null,
          firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets_for_the_feed,
          newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
          emptyMessage: L10n.of(context).could_not_find_any_quotes_of_this_post,
        ),
      ),
    );
  }
}
