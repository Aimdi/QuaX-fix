import 'package:flutter_test/flutter_test.dart';
import 'package:xta/client/client.dart';
import 'package:xta/tweet/threaded_conversation.dart';

TweetChain _chain(String id, {String? replyTo}) {
  final tweet = TweetWithCard()
    ..idStr = id
    ..inReplyToStatusIdStr = replyTo;
  return TweetChain(id: id, tweets: [tweet], isPinned: false);
}

void main() {
  group('buildThreadTree', () {
    test('nests replies under their parent', () {
      final chains = [
        _chain('focal'),
        _chain('r1', replyTo: 'focal'),
        _chain('r2', replyTo: 'r1'),
      ];
      final nodes = buildThreadTree(chains, 'focal');
      expect(nodes.map((n) => (n.chain.id, n.depth)).toList(), [
        ('focal', 0),
        ('r1', 1),
        ('r2', 2),
      ]);
    });
  });

  group('skipThreadSubtree', () {
    test('skips descendants in pre-order', () {
      final nodes = [
        ThreadNode(TweetChain(id: 'a', tweets: const [], isPinned: false), 1),
        ThreadNode(TweetChain(id: 'b', tweets: const [], isPinned: false), 2),
        ThreadNode(TweetChain(id: 'c', tweets: const [], isPinned: false), 3),
        ThreadNode(TweetChain(id: 'd', tweets: const [], isPinned: false), 1),
      ];
      expect(skipThreadSubtree(nodes, 1), 3);
    });
  });

  group('buildCappedThreadList', () {
    test('shows depth 0-2 and collapses deeper branches', () {
      final chains = [
        _chain('focal'),
        _chain('d1', replyTo: 'focal'),
        _chain('d2', replyTo: 'd1'),
        _chain('d3', replyTo: 'd2'),
        _chain('d4', replyTo: 'd3'),
      ];
      final display = buildCappedThreadList(buildThreadTree(chains, 'focal'));
      expect(display.whereType<ThreadDisplayNode>().map((n) => n.node.chain.id).toList(),
          ['focal', 'd1', 'd2']);
      final marker = display.whereType<ThreadContinueMarker>().single;
      expect(marker.target.chain.id, 'd3');
      expect(marker.indentDepth, 2);
    });

    test('keeps sibling branches after a collapsed subtree', () {
      final chains = [
        _chain('focal'),
        _chain('a', replyTo: 'focal'),
        _chain('a1', replyTo: 'a'),
        _chain('a2', replyTo: 'a1'),
        _chain('a3', replyTo: 'a2'),
        _chain('b', replyTo: 'focal'),
      ];
      final display = buildCappedThreadList(buildThreadTree(chains, 'focal'));
      expect(display.whereType<ThreadDisplayNode>().map((n) => n.node.chain.id).toList(),
          ['focal', 'a', 'a1', 'b']);
      expect(display.whereType<ThreadContinueMarker>().single.target.chain.id, 'a2');
    });

    test('marks connector flags on nested nodes', () {
      final chains = [
        _chain('focal'),
        _chain('r1', replyTo: 'focal'),
        _chain('r2', replyTo: 'r1'),
      ];
      final display = buildCappedThreadList(buildThreadTree(chains, 'focal'));
      final nodes = display.whereType<ThreadDisplayNode>().toList();
      expect(nodes[1].connectTop, isTrue);
      expect(nodes[1].connectBottom, isTrue);
      expect(nodes[2].connectTop, isTrue);
      expect(nodes[2].connectBottom, isFalse);
    });

    test('parent at cap depth gets bottom connector before continue row', () {
      final chains = [
        _chain('focal'),
        _chain('d1', replyTo: 'focal'),
        _chain('d2', replyTo: 'd1'),
        _chain('d3', replyTo: 'd2'),
      ];
      final display = buildCappedThreadList(buildThreadTree(chains, 'focal'));
      final capped = display.whereType<ThreadDisplayNode>().last;
      expect(capped.node.chain.id, 'd2');
      expect(capped.connectBottom, isTrue);
      expect(display.last, isA<ThreadContinueMarker>());
    });
  });
}
