import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/reddit/reddit_actions.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';
import 'package:quax/plugins/reddit/reddit_feed_list.dart';

String redditErrorMessage(L10n l10n, Object error) {
  if (error is RedditException) {
    final explanation = switch (error.kind) {
      RedditErrorKind.notConfigured => l10n.plugin_reddit_not_configured,
      RedditErrorKind.unauthorized => l10n.plugin_reddit_error_client_id,
      RedditErrorKind.blocked => l10n.plugin_reddit_error_blocked,
      RedditErrorKind.notFound => l10n.plugin_reddit_error_not_found,
      RedditErrorKind.rateLimited => l10n.plugin_reddit_error_rate_limited,
      RedditErrorKind.badResponse => l10n.plugin_reddit_error_response,
      RedditErrorKind.network => l10n.plugin_reddit_error_network,
    };

    // The translated sentence says what to do; the detail says what actually
    // happened. Without it a refusal, a timeout and a reshaped response all
    // read the same, and "it doesn't work" is all anyone can report back.
    return error.detail.isEmpty ? explanation : '$explanation\n\n${error.detail}';
  }
  return '$error';
}

/// Account-free Reddit reading: the subreddits you follow, newest first.
class RedditScreen extends StatelessWidget {
  final ScrollController scrollController;

  const RedditScreen({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).plugin_reddit_title),
        actions: const [RedditFeedActions()],
      ),
      body: RedditFeedList(scrollController: scrollController),
    );
  }
}
