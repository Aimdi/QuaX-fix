import 'package:flutter_test/flutter_test.dart';
import 'package:quax/plugins/reddit/reddit_comments.dart';

/// Shaped like old.reddit's comment area: `div.thing.comment` carrying its own
/// `entry`, with replies inside a `.child > .sitetable`.
String _comment(String id, String author, String body, {String score = '42 points', String replies = ''}) => '''
<div class="thing id-t1_$id comment" data-fullname="t1_$id" data-author="$author">
  <div class="entry unvoted">
    <p class="tagline">
      <a href="/user/$author" class="author">$author</a>
      <span class="score unvoted">$score</span>
      <time datetime="2026-07-01T10:00:00+00:00">1 hour ago</time>
    </p>
    <form class="usertext"><div class="usertext-body"><div class="md"><p>$body</p></div></div></form>
  </div>
  <div class="child">${replies.isEmpty ? '' : '<div class="sitetable listing">$replies</div>'}</div>
</div>
''';

String _page(String comments, {String post = ''}) => '''
<!doctype html><html><body>
  <div id="siteTable">$post</div>
  <div class="commentarea"><div class="sitetable nestedlisting">$comments</div></div>
</body></html>
''';

void main() {
  group('reading a thread', () {
    test('takes the author, body, score and time', () {
      final comment = parseComments(_page(_comment('a', 'someone', 'Well said'))).single;

      expect(comment.id, 'a');
      expect(comment.author, 'someone');
      expect(comment.body, 'Well said');
      expect(comment.score, 42);
      expect(comment.createdAt, DateTime.parse('2026-07-01T10:00:00Z').toLocal());
    });

    test('replies hang off the comment they answer', () {
      final page = _page(_comment('a', 'first', 'Question', replies: _comment('b', 'second', 'Answer')));

      final root = parseComments(page).single;
      expect(root.replies.single.id, 'b');
      expect(root.replies.single.body, 'Answer');
    });

    test('nesting goes as deep as the page does', () {
      final deep = _comment('a', 'x', 'one',
          replies: _comment('b', 'y', 'two', replies: _comment('c', 'z', 'three')));

      final root = parseComments(_page(deep)).single;
      expect(root.replies.single.replies.single.body, 'three');
      expect(root.totalCount, 3);
    });

    test('a comment does not swallow its replies\' text', () {
      // The entry has to be read off the comment itself, not the whole subtree.
      final page = _page(_comment('a', 'x', 'parent', replies: _comment('b', 'y', 'child')));

      expect(parseComments(page).single.body, 'parent');
    });

    test('siblings keep their order', () {
      final page = _page('${_comment('a', 'x', 'first')}${_comment('b', 'y', 'second')}');

      expect(parseComments(page).map((c) => c.id), ['a', 'b']);
    });

    test('a hidden score is absent rather than zero', () {
      const noScore = '''
<div class="thing comment" data-fullname="t1_n" data-author="x">
  <div class="entry"><div class="usertext-body"><div class="md">New here</div></div></div>
</div>
''';

      expect(parseComments(_page(noScore)).single.score, isNull);
    });

    test('the submitter is marked', () {
      const op = '''
<div class="thing comment" data-fullname="t1_o" data-author="poster">
  <div class="entry"><p class="tagline"><a class="author submitter">poster</a></p>
  <div class="usertext-body"><div class="md">Mine</div></div></div>
</div>
''';

      expect(parseComments(_page(op)).single.isSubmitter, isTrue);
    });
  });

  group('rows that are not comments', () {
    test('a "load more" control is skipped', () {
      const more = '<div class="thing morechildren" data-fullname="t1_more_x"></div>';

      expect(parseComments(_page('$more${_comment('a', 'x', 'real')}')).map((c) => c.id), ['a']);
    });

    test('a deleted comment with no body is left out', () {
      const empty = '<div class="thing comment" data-fullname="t1_d"><div class="entry"></div></div>';

      expect(parseComments(_page(empty)), isEmpty);
    });

    test('a page with no comment area yields none rather than throwing', () {
      expect(parseComments('<html><body>nothing</body></html>'), isEmpty);
      expect(parseComments(''), isEmpty);
    });
  });

  group('flattening for display', () {
    test('depth-first, with the depth carried alongside', () {
      final page = _page(_comment('a', 'x', 'one',
          replies: '${_comment('b', 'y', 'two', replies: _comment('c', 'z', 'three'))}${_comment('d', 'w', 'four')}'));

      final flat = flattenComments(parseComments(page));

      expect(flat.map((e) => e.comment.id), ['a', 'b', 'c', 'd']);
      expect(flat.map((e) => e.depth), [0, 1, 2, 1]);
    });

    test('nothing to flatten is an empty list', () {
      expect(flattenComments(const []), isEmpty);
    });
  });

  group('the post body on a thread page', () {
    test('is read when the listing did not carry it', () {
      const post = '''
<div class="thing" data-fullname="t3_p">
  <div class="expando"><form class="usertext"><div class="usertext-body"><div class="md">
    <p>The full text</p>
  </div></div></form></div>
</div>
''';

      expect(parseSelfText(_page('', post: post)), 'The full text');
    });

    test('a link post has none', () {
      expect(parseSelfText(_page(_comment('a', 'x', 'hi'))), isNull);
    });
  });
}
