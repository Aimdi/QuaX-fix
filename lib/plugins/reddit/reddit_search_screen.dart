import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';
import 'package:quax/plugins/reddit/reddit_listing_screen.dart';
import 'package:quax/plugins/reddit/reddit_post_card.dart';
import 'package:quax/plugins/reddit/reddit_screen.dart' show redditErrorMessage;
import 'package:quax/plugins/reddit/reddit_search_html.dart';
import 'package:quax/ui/errors.dart';

/// Searching Reddit for posts, subreddits and accounts.
///
/// Three separate searches rather than one ranked list, because they answer
/// different questions and Reddit serves them from different pages anyway.
class RedditSearchScreen extends StatefulWidget {
  const RedditSearchScreen({super.key});

  @override
  State<RedditSearchScreen> createState() => _RedditSearchScreenState();
}

class _RedditSearchScreenState extends State<RedditSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    final trimmed = value.trim();
    if (trimmed != _query) {
      setState(() => _query = trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(border: InputBorder.none, hintText: l10n.plugin_reddit_search_hint),
            onSubmitted: _search,
          ),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () => _search(_controller.text)),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.tweets),
              Tab(text: l10n.plugin_reddit_search_subreddits),
              Tab(text: l10n.plugin_reddit_search_users),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RedditSearchTab<RedditPost>(
              query: _query,
              search: (client, q) => client.searchPosts(q),
              itemBuilder: (context, post) => RedditPostCard(post: post, showSourceBadge: false),
            ),
            _RedditSearchTab<RedditSubredditResult>(
              query: _query,
              search: (client, q) => client.searchSubreddits(q),
              // Reddit's subreddit search misses exact names surprisingly
              // often, and the reader usually knows the one they want — so the
              // name they typed is always offered, whatever came back.
              leadingBuilder: (context, q) => _RedditNameRow(
                label: 'r/$q',
                icon: Icons.travel_explore,
                onTap: () => _open(context, RedditListingScreen.subreddit(q)),
              ),
              itemBuilder: (context, result) => _RedditSubredditRow(result: result),
            ),
            _RedditSearchTab<RedditUserResult>(
              query: _query,
              search: (client, q) => client.searchUsers(q),
              leadingBuilder: (context, q) => _RedditNameRow(
                label: 'u/$q',
                icon: Icons.person_outline,
                onTap: () => _open(context, RedditListingScreen.user(q)),
              ),
              itemBuilder: (context, result) => _RedditNameRow(
                label: 'u/${result.name}',
                icon: Icons.person_outline,
                onTap: () => _open(context, RedditListingScreen.user(result.name)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

/// One tab's results: run the search when the query changes, then list them.
class _RedditSearchTab<T> extends StatefulWidget {
  final String query;
  final Future<List<T>> Function(RedditClient client, String query) search;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Shown above the results, when there is a query. Used for the "go straight
  /// to this name" row.
  final Widget Function(BuildContext context, String query)? leadingBuilder;

  const _RedditSearchTab({
    super.key,
    required this.query,
    required this.search,
    required this.itemBuilder,
    this.leadingBuilder,
  });

  @override
  State<_RedditSearchTab<T>> createState() => _RedditSearchTabState<T>();
}

class _RedditSearchTabState<T> extends State<_RedditSearchTab<T>> with AutomaticKeepAliveClientMixin {
  List<T>? _results;
  Object? _error;
  String? _loaded;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _run();
  }

  @override
  void didUpdateWidget(_RedditSearchTab<T> old) {
    super.didUpdateWidget(old);
    _run();
  }

  Future<void> _run() async {
    final query = widget.query;
    if (query.isEmpty || query == _loaded) {
      return;
    }

    _loaded = query;
    setState(() {
      _error = null;
      _results = null;
    });

    try {
      final results = await widget.search(context.read<RedditClient>(), query);
      if (mounted && _loaded == query) {
        setState(() => _results = results);
      }
    } catch (e) {
      // A failed search must not lose the shortcut row: knowing the exact name
      // is often why someone opened this tab.
      if (mounted && _loaded == query) {
        setState(() => _error = e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = L10n.of(context);

    if (widget.query.isEmpty) {
      return const SizedBox.shrink();
    }

    final leading = widget.leadingBuilder?.call(context, widget.query);
    final results = _results;

    return ListView(
      children: [
        if (leading != null) leading,
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: FullPageErrorWidget(
              error: _error,
              stackTrace: null,
              prefix: redditErrorMessage(l10n, _error!),
              onRetry: () {
                _loaded = null;
                _run();
              },
            ),
          )
        else if (results == null)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (results.isEmpty && leading == null)
          Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.no_results)))
        else
          for (final item in results) widget.itemBuilder(context, item),
      ],
    );
  }
}

class _RedditSubredditRow extends StatelessWidget {
  final RedditSubredditResult result;

  const _RedditSubredditRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final subscribers = result.subscribers;
    final description = result.description;

    return ListTile(
      leading: const Icon(Icons.travel_explore),
      title: Text('r/${result.name}'),
      subtitle: description == null ? null : Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: subscribers == null ? null : Text('$subscribers'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RedditListingScreen.subreddit(result.name)),
      ),
    );
  }
}

/// A bare `r/name` or `u/name` row.
class _RedditNameRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RedditNameRow({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
  }
}
