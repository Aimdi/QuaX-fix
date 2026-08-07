import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_auth.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_listing_page.dart';
import 'package:xta/plugins/reddit/reddit_post_card.dart';
import 'package:xta/plugins/reddit/reddit_read_session.dart';
import 'package:xta/plugins/reddit/reddit_sort_sheet.dart';
import 'package:xta/plugins/reddit/reddit_states.dart';
import 'package:xta/ui/errors.dart';

class RedditListingState {
  final List<RedditPost>? posts;
  final String? after;
  final bool loadingMore;

  const RedditListingState({this.posts, this.after, this.loadingMore = false});

  RedditListingState copyWith({
    List<RedditPost>? posts,
    String? after,
    bool? loadingMore,
    bool clearAfter = false,
  }) => RedditListingState(
    posts: posts ?? this.posts,
    after: clearAfter ? null : after ?? this.after,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

class RedditListingStore extends Store<RedditListingState> {
  final RedditClient client;
  final BasePrefService prefs;
  final RedditAuth auth;
  final String? subreddit;
  final String? user;

  RedditListingStore({
    required this.client,
    required this.prefs,
    required this.subreddit,
    required this.user,
    RedditAuth? auth,
  }) : auth = auth ?? RedditAuth(),
       super(const RedditListingState());

  bool get canLoadMore => state.after != null;

  Future<void> refresh() async {
    await execute(() async {
      final listing = await _read();
      return RedditListingState(
        posts: _visiblePosts(listing.posts),
        after: listing.after,
      );
    });
  }

  Future<void> loadMore() async {
    final after = state.after;
    final posts = state.posts;
    if (after == null || posts == null || state.loadingMore) {
      return;
    }

    update(state.copyWith(loadingMore: true));
    try {
      final listing = await _read(after: after);
      update(
        RedditListingState(
          posts: appendRedditPosts(posts, _visiblePosts(listing.posts)),
          after: listing.after,
        ),
      );
    } catch (_) {
      update(state.copyWith(loadingMore: false));
    }
  }

  Future<RedditListing> _read({String? after}) async {
    final name = subreddit;
    if (name == null) {
      return client.fetchUserPosts(user!, after: after);
    }

    final session = await RedditReadSession.resolve(prefs: prefs, auth: auth);
    return session.fetchSubreddit(
      client,
      name,
      sort: storedRedditSort(prefs),
      timeFilter: storedRedditTimeFilter(prefs),
      after: after,
    );
  }

  List<RedditPost> _visiblePosts(List<RedditPost> posts) {
    return filterRedditPosts(posts, nsfwMode: storedRedditNsfwMode(prefs));
  }
}

class RedditListingBody extends StatefulWidget {
  final String? subreddit;
  final String? user;
  final ScrollController? scrollController;
  final bool showSourceBadge;

  const RedditListingBody.subreddit(
    String name, {
    super.key,
    this.scrollController,
    this.showSourceBadge = false,
  }) : subreddit = name,
       user = null;

  const RedditListingBody.user(
    String name, {
    super.key,
    this.scrollController,
    this.showSourceBadge = false,
  }) : subreddit = null,
       user = name;

  @override
  State<RedditListingBody> createState() => RedditListingBodyState();
}

class RedditListingBodyState extends State<RedditListingBody>
    with AutomaticKeepAliveClientMixin {
  RedditListingStore? _store;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store != null) {
      return;
    }
    _store = RedditListingStore(
      client: context.read<RedditClient>(),
      prefs: PrefService.of(context, listen: false),
      auth: context.read<RedditAuth>(),
      subreddit: widget.subreddit,
      user: widget.user,
    );
    unawaited(_store!.refresh());
  }

  @override
  void dispose() {
    _store?.destroy();
    super.dispose();
  }

  Future<void> refresh() => _store?.refresh() ?? Future.value();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = _store;
    if (store == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final l10n = L10n.of(context);
    return RefreshIndicator(
      onRefresh: store.refresh,
      child: ScopedBuilder<RedditListingStore, RedditListingState>.transition(
        store: store,
        onError: (_, error) => _error(context, l10n, store, error!),
        onLoading: (_) => const Center(child: CircularProgressIndicator()),
        onState: (_, state) => _body(context, l10n, store, state),
      ),
    );
  }

  Widget _error(
    BuildContext context,
    L10n l10n,
    RedditListingStore store,
    Object error,
  ) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: FullPageErrorWidget(
            error: error,
            stackTrace: null,
            prefix: redditErrorMessage(l10n, error),
            onRetry: store.refresh,
          ),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    L10n l10n,
    RedditListingStore store,
    RedditListingState state,
  ) {
    final posts = state.posts;
    if (posts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(l10n.no_results)),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: posts.length + (store.canLoadMore ? 1 : 0),
      itemBuilder: (context, index) => index >= posts.length
          ? _LoadMoreButton(
              loading: state.loadingMore,
              onPressed: store.loadMore,
            )
          : RedditPostCard(
              post: posts[index],
              showSourceBadge: widget.showSourceBadge,
            ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _LoadMoreButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(L10n.of(context).plugin_reddit_load_more),
        ),
      ),
    );
  }
}
