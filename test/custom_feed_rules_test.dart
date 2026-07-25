import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/group/custom_feed_rules.dart';

TweetChain _chain({
  String text = '',
  int likes = 0,
  int reposts = 0,
  int quotes = 0,
  bool sensitive = false,
  String? quotedText,
}) {
  final tweet = TweetWithCard()
    ..idStr = 't1'
    ..fullText = text
    ..favoriteCount = likes
    ..retweetCount = reposts
    ..quoteCount = quotes
    ..possiblySensitive = sensitive;

  if (quotedText != null) {
    tweet.quotedStatusWithCard = TweetWithCard()
      ..idStr = 't0'
      ..fullText = quotedText;
  }

  return TweetChain(id: 'c1', tweets: [tweet], isPinned: false);
}

void main() {
  group('parseMutedKeywords', () {
    test('splits on commas and newlines, keeping phrases whole', () {
      expect(parseMutedKeywords('bitcoin, black friday\nspoilers'), ['bitcoin', 'black friday', 'spoilers']);
    });

    test('is empty for nothing useful', () {
      expect(parseMutedKeywords(null), isEmpty);
      expect(parseMutedKeywords('   '), isEmpty);
      expect(parseMutedKeywords(',,\n,'), isEmpty);
    });

    test('round-trips through the stored form', () {
      final terms = ['bitcoin', 'black friday'];
      expect(parseMutedKeywords(joinMutedKeywords(terms)), terms);
    });
  });

  group('textMatchesMutedTerm', () {
    test('a single word matches whole words only', () {
      expect(textMatchesMutedTerm('I like cats', 'cat'), isFalse);
      expect(textMatchesMutedTerm('Look, a cat!', 'cat'), isTrue);
      expect(textMatchesMutedTerm('category error', 'cat'), isFalse);
    });

    test('is case-insensitive', () {
      expect(textMatchesMutedTerm('BITCOIN is up', 'bitcoin'), isTrue);
    });

    test('a phrase matches anywhere', () {
      expect(textMatchesMutedTerm('the black friday sales', 'black friday'), isTrue);
    });

    test('a term with punctuation matches as written', () {
      expect(textMatchesMutedTerm('buying \$TSLA today', '\$TSLA'), isTrue);
      expect(textMatchesMutedTerm('no ticker here', '\$TSLA'), isFalse);
    });

    test('handles non-Latin words', () {
      expect(textMatchesMutedTerm('Мне нравится кот', 'кот'), isTrue);
      expect(textMatchesMutedTerm('котлета на обед', 'кот'), isFalse);
    });

    test('an empty term never matches', () {
      expect(textMatchesMutedTerm('anything', '  '), isFalse);
    });
  });

  group('applyCustomFeedRules', () {
    test('passes everything through when no rule is set', () {
      final chains = [_chain(text: 'a', sensitive: true), _chain(text: 'b')];

      expect(applyCustomFeedRules(chains, const CustomFeedRules()), chains);
    });

    test('sfw keeps only non-sensitive posts, nsfw only sensitive ones', () {
      final chains = [_chain(text: 'clean'), _chain(text: 'spicy', sensitive: true)];

      expect(
        applyCustomFeedRules(chains, const CustomFeedRules(contentFilter: contentFilterSfw)).single.tweets.first.fullText,
        'clean',
      );
      expect(
        applyCustomFeedRules(chains, const CustomFeedRules(contentFilter: contentFilterNsfw)).single.tweets.first.fullText,
        'spicy',
      );
    });

    test('the likes threshold keeps posts at or above it', () {
      final chains = [_chain(text: 'quiet', likes: 9), _chain(text: 'loud', likes: 10)];

      final kept = applyCustomFeedRules(chains, const CustomFeedRules(minLikes: 10));

      expect(kept.map((c) => c.tweets.first.fullText), ['loud']);
    });

    test('the repost threshold counts reposts and quotes together', () {
      final chains = [
        _chain(text: 'reposts only', reposts: 6),
        _chain(text: 'split', reposts: 3, quotes: 3),
        _chain(text: 'too few', reposts: 2, quotes: 1),
      ];

      final kept = applyCustomFeedRules(chains, const CustomFeedRules(minRetweets: 6));

      expect(kept.map((c) => c.tweets.first.fullText), ['reposts only', 'split']);
    });

    test('a muted word hides the post', () {
      final chains = [_chain(text: 'the bitcoin thread'), _chain(text: 'unrelated')];

      final kept = applyCustomFeedRules(chains, const CustomFeedRules(mutedKeywords: ['bitcoin']));

      expect(kept.map((c) => c.tweets.first.fullText), ['unrelated']);
    });

    test('a muted word inside a quoted post also hides it', () {
      final chains = [_chain(text: 'look at this', quotedText: 'spoilers ahead')];

      expect(applyCustomFeedRules(chains, const CustomFeedRules(mutedKeywords: ['spoilers'])), isEmpty);
    });

    test('rules combine: a post must satisfy all of them', () {
      final chains = [
        _chain(text: 'popular but muted', likes: 500),
        _chain(text: 'popular and fine', likes: 500),
        _chain(text: 'fine but quiet', likes: 1),
      ];

      final kept = applyCustomFeedRules(
        chains,
        const CustomFeedRules(minLikes: 100, mutedKeywords: ['muted']),
      );

      expect(kept.map((c) => c.tweets.first.fullText), ['popular and fine']);
    });

    test('the cache key changes with every rule, so feeds do not share chunks', () {
      const base = CustomFeedRules();

      final keys = {
        base.cacheKey,
        const CustomFeedRules(contentFilter: contentFilterSfw).cacheKey,
        const CustomFeedRules(minLikes: 10).cacheKey,
        const CustomFeedRules(minRetweets: 10).cacheKey,
        const CustomFeedRules(mutedKeywords: ['x']).cacheKey,
      };

      expect(keys.length, 5);
    });
  });
}
