/// The state of one open thread.
///
/// Split out of the screen for two reasons: the screen was driving itself with
/// `setState`, which nothing else in the app does; and the fold was recomputed
/// inside `itemBuilder`, so every row walked the whole thread and a long page
/// cost O(n²) to scroll. The visible rows are derived once, here, whenever the
/// thread actually changes.
library;

import 'package:flutter_triple/flutter_triple.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_comments.dart';

/// A thread as the screen shows it.
class RedditThread {
  final RedditPost post;
  final String? selfText;
  final List<FlatComment> comments;
  final Set<String> collapsed;

  /// Reddit's comment order; null is the site's own default (best).
  final String? sort;

  /// Whether the comments have been read at all. Without it an empty list on
  /// first build would claim the post has no comments before anyone asked.
  final bool loaded;

  /// The rows to build, folds honoured. Derived, never passed in.
  final List<VisibleComment> rows;

  RedditThread({
    required this.post,
    this.selfText,
    this.comments = const [],
    this.collapsed = const {},
    this.sort,
    this.loaded = false,
  }) : rows = visibleComments(comments, collapsed);

  /// How many comments the thread holds, folded or not — what an empty state
  /// and a count both need.
  int get total => comments.length;

  RedditThread copyWith({
    RedditPost? post,
    String? selfText,
    List<FlatComment>? comments,
    Set<String>? collapsed,
    bool? loaded,
  }) {
    return RedditThread(
      post: post ?? this.post,
      selfText: selfText ?? this.selfText,
      comments: comments ?? this.comments,
      collapsed: collapsed ?? this.collapsed,
      sort: sort,
      loaded: loaded ?? this.loaded,
    );
  }
}

class RedditThreadStore extends Store<RedditThread> {
  final RedditClient client;

  RedditThreadStore(this.client, RedditPost post) : super(RedditThread(post: post, selfText: post.selfText));

  Future<void> load() async {
    final before = state;

    await execute(() async {
      final result = await client.fetchComments(before.post.permalink, sort: before.sort);

      return before.copyWith(
        post: adoptRedditPageMedia(before.post, result.postUrl, result.postImages),
        selfText: before.selfText ?? result.selfText,
        comments: flattenComments(result.comments),
        loaded: true,
      );
    });
  }

  /// Re-reads the thread in another order, dropping the folds with it: the
  /// comment ids that were folded mean nothing once the page is rebuilt.
  Future<void> sortBy(String? sort) async {
    final current = state;
    update(
      RedditThread(post: current.post, selfText: current.selfText, sort: sort == null || sort.isEmpty ? null : sort),
    );

    await load();
  }

  /// Folds a subtree, or opens it again.
  void toggleFold(String id) {
    final next = {...state.collapsed};
    next.contains(id) ? next.remove(id) : next.add(id);
    update(state.copyWith(collapsed: next));
  }

  /// Folds every top-level comment, or opens everything.
  ///
  /// Folded, the page becomes the list of arguments it is made of, which is the
  /// only way a thousand-comment thread is navigable on a phone at all.
  void toggleFoldAll() {
    final foldable = foldableTopLevelIds(state.comments);
    final allFolded = foldable.isNotEmpty && foldable.every(state.collapsed.contains);

    update(state.copyWith(collapsed: allFolded ? const {} : foldable));
  }

  bool get isFoldedThroughout {
    final foldable = foldableTopLevelIds(state.comments);
    return foldable.isNotEmpty && foldable.every(state.collapsed.contains);
  }
}

/// Fills in what the listing never carried.
///
/// A post that arrived through search names no link and no media — the search
/// page simply does not have them — so its own page is where they come from. A
/// link that is just the post's permalink says nothing and is not adopted;
/// everything else is, which is what turns "the post contained a file but it
/// isn't here" into the file being here.
RedditPost adoptRedditPageMedia(RedditPost post, String? url, List<String> images) {
  if (post.imageUrl != null) {
    return post;
  }

  final external = url != null && !_isOwnPermalink(url);
  if (!external && images.isEmpty) {
    return post;
  }

  return post.copyWith(
    url: external ? url : post.url,
    isSelf: external ? false : post.isSelf,
    galleryImages: images.isEmpty ? null : images,
  );
}

bool _isOwnPermalink(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.host.endsWith('reddit.com') && uri.path.contains('/comments/');
}
