import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_avatar.dart';
import 'package:xta/plugins/reddit/reddit_subreddit_avatar.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_comments.dart';
import 'package:xta/plugins/reddit/reddit_media_urls.dart';
import 'package:xta/plugins/reddit/reddit_listing_screen.dart';
import 'package:xta/plugins/reddit/reddit_post_media.dart';
import 'package:xta/plugins/reddit/reddit_screen.dart' show redditErrorMessage;
import 'package:xta/ui/dates.dart';
import 'package:xta/ui/errors.dart';

/// How far each level of replies is indented, and how deep that goes.
///
/// Reddit threads nest without limit; a phone cannot. Past this depth replies
/// keep their thread line but stop moving right, so a deep argument stays
/// readable instead of collapsing into a column one word wide.
const double kRedditIndentPerLevel = 12;
const int kRedditMaxIndentDepth = 8;

/// A post and its comments.
class RedditThreadScreen extends StatefulWidget {
  final RedditPost post;

  const RedditThreadScreen({super.key, required this.post});

  @override
  State<RedditThreadScreen> createState() => _RedditThreadScreenState();
}

class _RedditThreadScreenState extends State<RedditThreadScreen> {
  late RedditPost _post = widget.post;
  List<FlatComment>? _comments;
  String? _selfText;
  Object? _error;

  /// Reddit's comment orders; null is the site's default (best).
  String? _sort;
  final _collapsed = <String>{};

  @override
  void initState() {
    super.initState();
    _selfText = widget.post.selfText;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final result = await context.read<RedditClient>().fetchComments(_post.permalink, sort: _sort);
      if (!mounted) return;
      setState(() {
        _comments = flattenComments(result.comments);
        _selfText ??= result.selfText;
        _adoptPageMedia(result.postUrl, result.postImages);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  /// Fills in what the listing never carried.
  ///
  /// A post that arrived through search names no link and no media — the search
  /// page simply does not have them — so its own page is where they come from.
  /// A link that is just the post's permalink says nothing and is not adopted;
  /// everything else is, which is what turns "the post contained a file but it
  /// isn't here" into the file being here.
  void _adoptPageMedia(String? url, List<String> images) {
    if (_post.imageUrl != null) {
      return;
    }

    final external = url != null && !_isOwnPermalink(url);
    final gallery = collapseRedditImageUrls(images);
    if (!external && gallery.isEmpty) {
      return;
    }

    // data-url already is the picture — expando imgs are preview variants of
    // that same file, not a gallery. Real galleries use reddit.com/gallery/…
    // which does not resolve as an image URL.
    final urlIsImage = external && redditImageUrl(url) != null;

    _post = _post.copyWith(
      url: external ? url : _post.url,
      isSelf: external ? false : _post.isSelf,
      galleryImages: urlIsImage || gallery.isEmpty ? null : gallery,
    );
  }

  bool _isOwnPermalink(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.host.endsWith('reddit.com') && uri.path.contains('/comments/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final comments = _comments;

    return Scaffold(
      appBar: AppBar(
        title: Text('r/${widget.post.subreddit}'),
        actions: [
          PopupMenuButton<String>(
            tooltip: l10n.plugin_reddit_sort,
            icon: const Icon(Icons.sort),
            initialValue: _sort ?? '',
            onSelected: (value) {
              setState(() {
                _sort = value.isEmpty ? null : value;
                _comments = null;
                _collapsed.clear();
              });
              _load();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: '', child: Text(l10n.plugin_reddit_sort_best)),
              PopupMenuItem(value: 'top', child: Text(l10n.plugin_reddit_sort_top)),
              PopupMenuItem(value: 'new', child: Text(l10n.plugin_reddit_sort_new)),
              PopupMenuItem(value: 'controversial', child: Text(l10n.plugin_reddit_sort_controversial)),
              PopupMenuItem(value: 'old', child: Text(l10n.plugin_reddit_sort_old)),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          // One header plus the flattened tree: nesting the widgets instead
          // would build every reply of every collapsed branch up front.
          itemCount: 1 + (comments == null ? 1 : visibleComments(comments, _collapsed).length),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _header(context);
            }
            if (comments == null) {
              return _pending(context, l10n);
            }
            final visible = visibleComments(comments, _collapsed)[index - 1];
            if (visible.entry.comment.isStub) {
              return _stubRow(context, visible.entry);
            }
            return _commentRow(context, visible.entry, hidden: visible.hidden);
          },
        ),
      ),
    );
  }

  Widget _pending(BuildContext context, L10n l10n) {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: redditErrorMessage(l10n, error),
          onRetry: _load,
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final post = _post;
    final date = post.createdAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.title, style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
            child: Row(
              children: [
                RedditSubredditAvatar(subreddit: post.subreddit, size: 22),
                const SizedBox(width: 6),
                if (post.author != null) Text('u/${post.author}'),
                if (date != null) ...[
                  const SizedBox(width: 8),
                  Text(createRelativeDate(date)),
                ],
                const Spacer(),
                Text('${post.score} · ${post.commentCount}'),
              ],
            ),
          ),
          // The same block the feed card uses, so a picture post opens on its
          // picture rather than on a link to one.
          RedditPostMedia(post: post, padding: const EdgeInsets.only(top: 10)),
          if (_selfText != null) ...[
            const SizedBox(height: 10),
            Text(_selfText!, style: theme.textTheme.bodyMedium),
          ],
          const Divider(height: 24),
        ],
      ),
    );
  }

  /// A row that folds on tap. [hidden] is how many replies its fold is
  /// holding, shown as a chip so a collapsed argument says how big it was.
  Widget _commentRow(BuildContext context, FlatComment entry, {int hidden = 0}) {
    final theme = Theme.of(context);
    final comment = entry.comment;
    final depth = entry.depth;
    final folded = _collapsed.contains(comment.id);
    final indent = kRedditIndentPerLevel * (depth > kRedditMaxIndentDepth ? kRedditMaxIndentDepth : depth);

    return InkWell(
      onTap: () => setState(() => folded ? _collapsed.remove(comment.id) : _collapsed.add(comment.id)),
      child: Padding(
      padding: EdgeInsets.fromLTRB(12 + indent, 6, 12, 6),
      child: Container(
        padding: EdgeInsets.only(left: depth == 0 ? 0 : 8),
        decoration: depth == 0
            ? null
            : BoxDecoration(
                border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant, width: 2)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
              child: Row(
                children: [
                  RedditAvatar(name: comment.author, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: GestureDetector(
                      // A name in a thread is a way to the rest of what they
                      // posted, the same as it is on the card.
                      onTap: comment.author == null
                          ? null
                          : () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => RedditListingScreen.user(comment.author!))),
                      child: Text(
                        comment.author == null ? '' : 'u/${comment.author}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: comment.isSubmitter ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                  ),
                  if (comment.score != null) ...[
                    const SizedBox(width: 8),
                    Text('${comment.score}'),
                  ],
                  if (comment.createdAt != null) ...[
                    const SizedBox(width: 8),
                    Text(createRelativeDate(comment.createdAt!)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 2),
            if (folded)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('+${hidden + 1}', style: theme.textTheme.labelSmall),
              )
            else ...[
              if (comment.body.isNotEmpty) Text(comment.body, style: theme.textTheme.bodyMedium),
              RedditCommentImages(urls: comment.mediaUrls),
            ],
          ],
        ),
      ),
      ),
    );
  }

  /// Replies Reddit held back. The row says how many and opens the subtree's
  /// own page, rather than the thread ending mid-air with no sign anything is
  /// missing — which is what silently dropping these rows did.
  Widget _stubRow(BuildContext context, FlatComment entry) {
    final theme = Theme.of(context);
    final comment = entry.comment;
    final depth = entry.depth;
    final indent = kRedditIndentPerLevel * (depth > kRedditMaxIndentDepth ? kRedditMaxIndentDepth : depth);
    final count = (comment.moreCount ?? -1) > 0 ? ' · ${comment.moreCount}' : '';

    return InkWell(
      onTap: comment.permalink == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RedditThreadScreen(post: _post.copyWith(permalink: comment.permalink)),
                ),
              ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.0 + indent, 10, 12, 10),
        child: Row(
          children: [
            Icon(Icons.subdirectory_arrow_right, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '${L10n.of(context).plugin_reddit_more_replies}$count',
              style: theme.textTheme.bodySmall!
                  .copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
