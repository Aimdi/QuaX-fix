/// Unfollowing a subscription on whatever network it came from.
///
/// [SubscriptionsModel.toggleSubscribe] only ever knew X accounts and saved
/// searches, so the unsubscribe item on a followed subreddit, publication or
/// Threads account silently did nothing. Each plugin's store owns its own
/// removal — it has to, or its own tab would go on listing what was removed —
/// so the answer lives here, where the stores are in reach.
library;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/plugins/bluesky/bluesky_store.dart';
import 'package:xta/plugins/mastodon/mastodon_store.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';
import 'package:xta/plugins/substack/substack_store.dart';
import 'package:xta/plugins/threads/threads_store.dart';

/// Unfollows [subscription], or returns false when it is not a plugin's to
/// remove — an X account or a saved search, which the subscriptions model
/// handles itself.
Future<bool> unfollowSubscription(BuildContext context, Subscription subscription) async {
  switch (subscription) {
    case RedditSubscription(:final name):
      await context.read<RedditSubredditsStore>().remove(name);
    case SubstackSubscription(:final id):
      await context.read<SubstackPublicationsStore>().remove(id);
    case ThreadsSubscription(:final id):
      await context.read<ThreadsAccountsStore>().remove(id);
    case BlueskySubscription(:final id):
      await context.read<BlueskyAccountsStore>().remove(id);
    case MastodonSubscription(:final id):
      await context.read<MastodonAccountsStore>().remove(id);
    default:
      return false;
  }

  return true;
}
