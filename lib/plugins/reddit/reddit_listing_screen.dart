import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_listing_body.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';
import 'package:xta/subscriptions/users_model.dart';

/// A list of Reddit posts under a title.
///
/// A subreddit and an account differ only in where the posts come from and
/// whether the title can be followed, so they are one screen rather than two
/// that would drift apart.
class RedditListingScreen extends StatelessWidget {
  final String? subreddit;
  final String? user;

  const RedditListingScreen.subreddit(String name, {super.key})
    : subreddit = name,
      user = null;

  const RedditListingScreen.user(String name, {super.key})
    : user = name,
      subreddit = null;

  String get title => subreddit != null ? 'r/$subreddit' : 'u/$user';

  @override
  Widget build(BuildContext context) {
    final subreddit = this.subreddit;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (subreddit != null) RedditFollowButton(subreddit: subreddit),
        ],
      ),
      body: subreddit == null
          ? RedditListingBody.user(user!)
          : RedditListingBody.subreddit(subreddit),
    );
  }
}

/// Follows or unfollows a subreddit, reflecting whichever it currently is.
///
/// Observes the store rather than reading it once, so the label flips the
/// moment the list changes — including when it is changed from somewhere else.
class RedditFollowButton extends StatelessWidget {
  final String subreddit;

  const RedditFollowButton({super.key, required this.subreddit});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return ScopedBuilder<RedditSubredditsStore, List<String>>(
      store: context.read<RedditSubredditsStore>(),
      onState: (context, names) {
        final followed = isFollowedSubreddit(names, subreddit);

        return TextButton.icon(
          icon: Icon(followed ? Icons.check : Icons.add, size: 18),
          label: Text(followed ? l10n.unsubscribe : l10n.subscribe),
          onPressed: () =>
              toggleRedditFollow(context, subreddit, followed: followed),
        );
      },
    );
  }
}

/// Subreddit names are stored as the reader typed them but compared as Reddit
/// does, which is case-insensitively.
bool isFollowedSubreddit(List<String> names, String subreddit) =>
    names.any((e) => e.toLowerCase() == subreddit.toLowerCase());

/// Adds or removes a subreddit, and tells the subscription list about it so the
/// group editor sees the change without a restart.
Future<void> toggleRedditFollow(
  BuildContext context,
  String subreddit, {
  required bool followed,
}) async {
  final store = context.read<RedditSubredditsStore>();
  final subscriptions = context.read<SubscriptionsModel>();

  followed ? await store.remove(subreddit) : await store.add(subreddit);
  await subscriptions.reloadSubscriptions();
}
