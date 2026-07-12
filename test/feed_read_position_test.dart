import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/group/feed_read_position.dart';

TweetChain chain(String id, DateTime? createdAt) {
  final tweet = TweetWithCard()..createdAt = createdAt;
  return TweetChain(id: id, tweets: [tweet], isPinned: false);
}

void main() {
  final t0 = DateTime(2026, 7, 1, 12);

  test('isChainSeen matches by id and by timestamp', () {
    final position = FeedReadPosition(chainId: 'a', chainCreatedAt: t0);
    expect(isChainSeen(chain('a', null), position), isTrue);
    expect(isChainSeen(chain('b', t0.subtract(const Duration(minutes: 1))), position), isTrue);
    expect(isChainSeen(chain('b', t0), position), isTrue);
    expect(isChainSeen(chain('b', t0.add(const Duration(minutes: 1))), position), isFalse);
    expect(isChainSeen(chain('b', null), position), isFalse);
  });

  test('caughtUpBoundaryIndex finds the first seen chain below new ones', () {
    final position = FeedReadPosition(chainId: 'seen', chainCreatedAt: t0);
    final newer = chain('n', t0.add(const Duration(hours: 1)));
    final older = chain('o', t0.subtract(const Duration(hours: 1)));

    expect(caughtUpBoundaryIndex([newer, newer, older], position), 2);
    // Nothing new: the boundary would be the very top, so no divider.
    expect(caughtUpBoundaryIndex([older, older], position), isNull);
    // Boundary not loaded yet.
    expect(caughtUpBoundaryIndex([newer, newer], position), isNull);
    expect(caughtUpBoundaryIndex([], position), isNull);
  });
}
