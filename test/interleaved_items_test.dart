import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/interleaved_items.dart';

TweetChain _chainAt(String id, List<DateTime?> dates) {
  final tweets = dates.map((date) {
    final tweet = TweetWithCard();
    tweet.idStr = id;
    tweet.createdAt = date;
    return tweet;
  }).toList();

  return TweetChain(id: id, tweets: tweets, isPinned: false);
}

InterleavedItem _item(DateTime date) => (date: date, build: (_) => const SizedBox.shrink());

DateTime _at(int day) => DateTime.utc(2026, 1, day);

void main() {
  group('newestDateOf', () {
    test('takes the newest post in the chain, not the first', () {
      expect(newestDateOf(_chainAt('1', [_at(3), _at(9), _at(5)])), _at(9));
    });

    test('a chain with no dates has none', () {
      expect(newestDateOf(_chainAt('1', [null])), isNull);
    });
  });

  group('placeInterleaved', () {
    test('an item newer than everything goes above the first chain', () {
      final chains = [_chainAt('a', [_at(5)]), _chainAt('b', [_at(3)])];

      final buckets = placeInterleaved(chains, [_item(_at(9))]);

      expect(buckets, hasLength(3));
      expect(buckets[0], hasLength(1));
      expect(buckets[1], isEmpty);
      expect(buckets.last, isEmpty);
    });

    test('an item lands directly above the first chain older than it', () {
      final chains = [_chainAt('a', [_at(9)]), _chainAt('b', [_at(5)]), _chainAt('c', [_at(1)])];

      final buckets = placeInterleaved(chains, [_item(_at(7))]);

      expect(buckets[0], isEmpty);
      expect(buckets[1], hasLength(1), reason: 'newer than the 5th, older than the 9th');
      expect(buckets[2], isEmpty);
    });

    test('an item older than every loaded chain waits at the end', () {
      // Not dropped: the feed has simply not paged down to it yet, and it moves
      // up as more chains load.
      final chains = [_chainAt('a', [_at(9)])];

      final buckets = placeInterleaved(chains, [_item(_at(1))]);

      expect(buckets.first, isEmpty);
      expect(buckets.last, hasLength(1));
    });

    test('several items keep newest-first order within a bucket', () {
      final chains = [_chainAt('a', [_at(1)])];

      final buckets = placeInterleaved(chains, [_item(_at(5)), _item(_at(9)), _item(_at(7))]);

      expect(buckets.first.map((e) => e.date), [_at(9), _at(7), _at(5)]);
    });

    test('a chain with no date is passed over rather than guessed at', () {
      final chains = [_chainAt('a', [null]), _chainAt('b', [_at(1)])];

      final buckets = placeInterleaved(chains, [_item(_at(5))]);

      expect(buckets[0], isEmpty);
      expect(buckets[1], hasLength(1));
    });

    test('no items means empty buckets, one per chain plus the tail', () {
      final buckets = placeInterleaved([_chainAt('a', [_at(1)])], const []);

      expect(buckets, hasLength(2));
      expect(buckets.every((b) => b.isEmpty), isTrue);
    });

    test('items with no chains at all still come back', () {
      final buckets = placeInterleaved(const [], [_item(_at(5))]);

      expect(buckets, hasLength(1));
      expect(buckets.single, hasLength(1));
    });
  });
}
