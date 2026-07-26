/// Placing non-X posts among X posts in one timeline.
///
/// The feed pages on X's cursors, and nothing else can page on them — a
/// Substack publication has its own, unrelated pagination. So rather than
/// making the list generic over its item type (which would take the feed cache,
/// the saved posts and the media grid with it), other sources are handed to the
/// list as dated items and slotted between the chains it already has.
library;

import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';

typedef InterleavedItem = ({DateTime date, WidgetBuilder build});

/// The newest post in a chain, which is where the chain sits in a timeline.
DateTime? newestDateOf(TweetChain chain) {
  DateTime? newest;
  for (final tweet in chain.tweets) {
    final date = tweet.createdAt;
    if (date != null && (newest == null || date.isAfter(newest))) {
      newest = date;
    }
  }
  return newest;
}

/// Buckets [items] against [chains], newest first.
///
/// Returns one bucket per chain plus a trailing bucket: bucket `i` holds the
/// items that belong immediately above chain `i`, and the last holds those
/// older than every chain loaded so far.
///
/// Items older than the oldest loaded chain deliberately land in the trailing
/// bucket rather than being dropped — the feed has simply not paged down to
/// them yet, and they move up as it does.
List<List<InterleavedItem>> placeInterleaved(List<TweetChain> chains, List<InterleavedItem> items) {
  final buckets = List.generate(chains.length + 1, (_) => <InterleavedItem>[], growable: false);
  if (items.isEmpty) {
    return buckets;
  }

  final sorted = [...items]..sort((a, b) => b.date.compareTo(a.date));
  final dates = chains.map(newestDateOf).toList(growable: false);

  for (final item in sorted) {
    var slot = chains.length;
    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      // A chain with no date at all cannot be compared against, so the item
      // goes on past it rather than being wedged in at an arbitrary point.
      if (date != null && item.date.isAfter(date)) {
        slot = i;
        break;
      }
    }
    buckets[slot].add(item);
  }

  return buckets;
}
