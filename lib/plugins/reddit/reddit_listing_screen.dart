import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';
import 'package:quax/plugins/reddit/reddit_post_card.dart';
import 'package:quax/plugins/reddit/reddit_screen.dart' show redditErrorMessage;
import 'package:quax/plugins/reddit/reddit_store.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/errors.dart';

/// A list of Reddit posts under a title.
///
/// A subreddit and an account differ only in where the posts come from and
/// whether the title can be followed, so they are one screen rather than two
/// that would drift apart.
class RedditListingScreen extends StatefulWidget {
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
  State<RedditListingScreen> createState() => _RedditListingScreenState();
}

class _RedditListingScreenState extends State<RedditListingScreen> {
  List<RedditPost>? _posts;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final posts = await _read();
      if (mounted) {
        setState(() => _posts = posts);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  /// Reads through whichever route the reader chose, the same as the feed —
  /// a screen that quietly ignored the source setting would be a way around it.
  Future<List<RedditPost>> _read() async {
    final client = context.read<RedditClient>();
    final subreddit = widget.subreddit;
    if (subreddit == null) {
      return (await client.fetchUserPosts(widget.user!)).posts;
    }

    final prefs = PrefService.of(context, listen: false);
    final listing = await client.fetchSubreddit(
      subreddit,
      clientId: prefs.get<String>(optionPluginRedditClientId) ?? '',
      preferPublic: prefs.get<String>(optionPluginRedditSource) == redditSourcePublic,
    );

    return listing.posts;
  }

  @override
  Widget build(BuildContext context) {
    final subreddit = widget.subreddit;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [if (subreddit != null) RedditFollowButton(subreddit: subreddit)],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = L10n.of(context);
    final error = _error;
    if (error != null) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: FullPageErrorWidget(
            error: error,
            stackTrace: null,
            prefix: redditErrorMessage(l10n, error),
            onRetry: _load,
          ),
        ),
      ]);
    }

    final posts = _posts;
    if (posts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return ListView(children: [
        Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.no_results))),
      ]);
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) => RedditPostCard(post: posts[index], showSourceBadge: false),
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
          onPressed: () => toggleRedditFollow(context, subreddit, followed: followed),
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
Future<void> toggleRedditFollow(BuildContext context, String subreddit, {required bool followed}) async {
  final store = context.read<RedditSubredditsStore>();
  final subscriptions = context.read<SubscriptionsModel>();

  followed ? await store.remove(subreddit) : await store.add(subreddit);
  await subscriptions.reloadSubscriptions();
}
