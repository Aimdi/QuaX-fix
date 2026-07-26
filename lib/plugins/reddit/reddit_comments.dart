/// Reading a comment thread out of old.reddit.com's HTML.
///
/// Same reasoning as the listing scraper: the JSON is gone, the old site still
/// renders threads to anyone, and the `data-*` attributes are the stable part.
/// Nesting comes from the markup's own shape — each comment holds its replies
/// in a `.child` block — so the tree is read recursively rather than guessed at
/// from indentation.
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// One comment, with whatever replies hang off it.
class RedditComment {
  final String id;
  final String? author;
  final String body;

  /// Null when Reddit is hiding the score, which it does for new comments.
  final int? score;

  /// Reddit's own wording — "4 hours ago" — rather than a parsed date. The page
  /// gives a machine-readable timestamp too, and that is preferred; this is the
  /// fallback when it is missing.
  final DateTime? createdAt;

  /// Marked by Reddit as the submitter of the post.
  final bool isSubmitter;

  final List<RedditComment> replies;

  const RedditComment({
    required this.id,
    required this.body,
    this.author,
    this.score,
    this.createdAt,
    this.isSubmitter = false,
    this.replies = const [],
  });

  /// This comment and everything under it, which is what a flat list needs.
  int get totalCount => 1 + replies.fold<int>(0, (sum, reply) => sum + reply.totalCount);
}

/// A comment flattened for display, keeping how deep it sat.
typedef FlatComment = ({RedditComment comment, int depth});

/// Walks a tree into the list a `ListView` can build, depth carried alongside
/// so each row can be indented without nesting widgets inside widgets.
List<FlatComment> flattenComments(List<RedditComment> comments, {int depth = 0}) {
  final flat = <FlatComment>[];
  for (final comment in comments) {
    flat.add((comment: comment, depth: depth));
    flat.addAll(flattenComments(comment.replies, depth: depth + 1));
  }
  return flat;
}

int? _score(Element entry) {
  // "42 points", "1 point", or "" when Reddit is hiding it.
  final text = entry.querySelector('.score.unvoted')?.text ?? entry.querySelector('.score')?.text;
  if (text == null) {
    return null;
  }
  final digits = RegExp(r'-?\d+').firstMatch(text.replaceAll(',', ''));
  return digits == null ? null : int.tryParse(digits.group(0)!);
}

DateTime? _createdAt(Element entry) {
  final raw = entry.querySelector('time')?.attributes['datetime'];
  return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
}

RedditComment? _commentFrom(Element thing) {
  final fullname = thing.attributes['data-fullname'];
  // `more` rows ("load 40 more comments") are controls, not comments.
  if (fullname == null || !fullname.startsWith('t1_')) {
    return null;
  }

  // Only this comment's own entry, never a reply's: `querySelector` searches
  // the whole subtree, so the child block has to be excluded explicitly.
  final entry = thing.children.firstWhere(
    (e) => e.classes.contains('entry'),
    orElse: () => Element.tag('div'),
  );

  final body = entry.querySelector('.usertext-body .md')?.text.trim() ?? '';
  if (body.isEmpty) {
    return null;
  }

  return RedditComment(
    id: fullname.substring(3),
    author: thing.attributes['data-author'] ?? entry.querySelector('a.author')?.text.trim(),
    body: body,
    score: _score(entry),
    createdAt: _createdAt(entry),
    isSubmitter: entry.querySelector('.author.submitter') != null,
    replies: _repliesOf(thing),
  );
}

/// The comments nested directly inside [thing].
List<RedditComment> _repliesOf(Element thing) {
  final child = thing.children.where((e) => e.classes.contains('child')).firstOrNull;
  if (child == null) {
    return const [];
  }

  final listing = child.children.where((e) => e.classes.contains('sitetable')).firstOrNull;
  return listing == null ? const [] : _commentsIn(listing);
}

/// Direct comment children of a listing block, in order.
List<RedditComment> _commentsIn(Element listing) {
  final comments = <RedditComment>[];
  for (final thing in listing.children.where((e) => e.classes.contains('thing'))) {
    final comment = _commentFrom(thing);
    if (comment != null) {
      comments.add(comment);
    }
  }
  return comments;
}

/// The comment tree of a post page.
///
/// An unreadable page yields no comments rather than throwing — the post itself
/// is still worth showing.
List<RedditComment> parseComments(String body) {
  final document = html.parse(body);

  final area = document.querySelector('.commentarea .sitetable') ?? document.querySelector('.nestedlisting');
  return area == null ? const [] : _commentsIn(area);
}

/// The post's own text on a comment page, for a self post whose body the
/// listing did not carry.
String? parseSelfText(String body) {
  final document = html.parse(body);
  final text = document.querySelector('#siteTable .expando .usertext-body .md')?.text.trim() ??
      document.querySelector('#siteTable .usertext-body .md')?.text.trim();

  return text == null || text.isEmpty ? null : text;
}
