/// How a subscription is drawn and where tapping it leads, whichever network
/// it belongs to.
///
/// The group editor had worked this out for its member list; the subscriptions
/// list had not, so everything that was not an X account fell through to a
/// saved-search row — a followed subreddit wore a search icon, said it was a
/// search term, and opened X's search for its own name. Both read this now, so
/// a network taught to one is taught to the other.
library;

import 'package:flutter/material.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/bluesky/bluesky_butterfly_icon.dart';
import 'package:xta/plugins/bluesky/bluesky_profile_screen.dart';
import 'package:xta/plugins/mastodon/mastodon_profile_screen.dart';
import 'package:xta/plugins/reddit/reddit_avatar.dart';
import 'package:xta/plugins/reddit/reddit_listing_screen.dart';
import 'package:xta/plugins/substack/substack_archive_screen.dart';
import 'package:xta/plugins/substack/substack_store.dart';
import 'package:xta/plugins/threads/threads_profile_screen.dart';
import 'package:xta/user.dart';

/// What a subscription is, under its name.
///
/// A subreddit and a publication have no `@handle`; labelling them with one
/// made a subreddit read as an X account that had lost its avatar.
String subscriptionSubtitle(Subscription subscription) => switch (subscription) {
  SearchSubscription() => L10n.current.search_term,
  RedditSubscription(:final name) => 'r/$name',
  SubstackSubscription(:final baseUrl) => Uri.tryParse(baseUrl)?.host ?? baseUrl,
  _ => '@${subscription.screenName}',
};

/// The mark shown beside a subscription's name.
Widget subscriptionAvatar(Subscription subscription, {double size = 40}) => switch (subscription) {
  SearchSubscription() => SizedBox(width: size + 8, child: const Icon(Icons.search)),
  RedditSubscription(:final name) => RedditAvatar(name: 'r/$name', size: size),
  BlueskySubscription() => Stack(
    alignment: Alignment.bottomRight,
    children: [
      UserAvatar(uri: subscription.profileImageUrlHttps),
      const BlueskyButterflyIcon(size: 12),
    ],
  ),
  _ => UserAvatar(uri: subscription.profileImageUrlHttps),
};

/// Where tapping a subscription goes, or null when that network has no screen
/// to open — better nothing than the wrong network's search results.
Widget Function()? subscriptionDestination(Subscription subscription) => switch (subscription) {
  RedditSubscription(:final name) => () => RedditListingScreen.subreddit(name),
  SubstackSubscription() => () => SubstackArchiveScreen(publication: publicationOf(subscription)),
  ThreadsSubscription(:final id) => () => ThreadsProfileScreen(username: id),
  BlueskySubscription(:final id) => () => BlueskyProfileScreen(actor: id),
  MastodonSubscription(:final id) => () => MastodonProfileScreen(acct: id),
  _ => null,
};
