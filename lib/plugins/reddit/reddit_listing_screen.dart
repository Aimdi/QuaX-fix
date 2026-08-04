import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_listing_page.dart';
import 'package:xta/plugins/reddit/reddit_post_card.dart';
import 'package:xta/plugins/reddit/reddit_read_session.dart';
import 'package:xta/plugins/reddit/reddit_screen.dart' show redditErrorMessage;
import 'package:xta/plugins/reddit/reddit_sort_sheet.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';
import 'package:xta/subscriptions/users_model.dart';
import 'package:xta/ui/errors.dart';

/// How close to the end of the list (in px) triggers the next page.
const double _loadMoreExtent = 400;

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
  String? _after;
  bool _loadingMore = false;
  Object? _loadingMoreError;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _posts = null;
      _after = null;
      _loadingMore = false;
      _loadingMoreError = null;
    });
    try {
      final listing = await _read();
      if (mounted) {
        setState(() {
          _posts = listing.posts;
          _after = listing.after;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _loadMore() async {
    final after = _after;
    if (after == null || _loadingMore || _posts == null) {
      return;
    }
    setState(() {
      _loadingMore = true;
      _loadingMoreError = null;
    });
    try {
      final listing = await _read(after: after);
      if (!mounted) {
        return;
      }
      setState(() {
        _posts = appendRedditPosts(_posts!, listing.posts);
        _after = listing.after;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _loadingMoreError = e;
        });
      }
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (_after == null || _loadingMore || _posts == null) {
      return false;
    }
    if (notification.metrics.pixels < notification.metrics.maxScrollExtent - _loadMoreExtent) {
      return false;
    }
    // After a failure, wait for scroll-end near the bottom so continuous
    // ScrollUpdate notifications do not hammer the next page.
    if (_loadingMoreError != null && notification is! ScrollEndNotification) {
      return false;
    }
    _loadMore();
    return false;
  }

  /// Reads through whichever route the reader chose, the same as the feed —
  /// a screen that quietly ignored the source setting would be a way around it.
  Future<RedditListing> _read({String? after}) async {
    final client = context.read<RedditClient>();
    final subreddit = widget.subreddit;
    if (subreddit == null) {
      return client.fetchUserPosts(widget.user!, after: after);
    }

    final prefs = PrefService.of(context, listen: false);
    final session = await RedditReadSession.resolve(prefs: prefs);
    return session.fetchSubreddit(
      client,
      subreddit,
      sort: storedRedditSort(prefs),
      after: after,
    );
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

    final showSpinner = _loadingMore;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.builder(
        itemCount: posts.length + (showSpinner ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return RedditPostCard(post: posts[index], showSourceBadge: false);
        },
      ),
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
