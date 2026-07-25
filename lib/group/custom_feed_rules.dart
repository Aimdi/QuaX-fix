import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';

/// Everything a custom feed filters on, beyond replies and reposts.
///
/// Kept as plain data with no Flutter or database dependency so the filtering
/// is straightforward to test.
class CustomFeedRules {
  /// `sfw` / `default` / `nsfw`, from [contentFilterDefault] and friends.
  final String contentFilter;

  /// Hide posts below this many likes. 0 disables the threshold.
  final int minLikes;

  /// Hide posts below this many reposts. 0 disables the threshold.
  final int minRetweets;

  /// Hide posts containing any of these terms.
  final List<String> mutedKeywords;

  const CustomFeedRules({
    this.contentFilter = contentFilterDefault,
    this.minLikes = 0,
    this.minRetweets = 0,
    this.mutedKeywords = const [],
  });

  bool get isEmpty =>
      contentFilter == contentFilterDefault && minLikes == 0 && minRetweets == 0 && mutedKeywords.isEmpty;

  /// Part of the feed cache key: two feeds with different rules must not share
  /// cached chunks.
  String get cacheKey => '$contentFilter|$minLikes|$minRetweets|${mutedKeywords.join(",")}';
}

/// Splits what the user typed into terms. Commas and newlines separate, so a
/// multi-word phrase stays one term.
List<String> parseMutedKeywords(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }
  return raw
      .split(RegExp(r'[,\n]'))
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
}

String joinMutedKeywords(List<String> keywords) => keywords.join(', ');

final RegExp _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Whether [text] contains [term], case-insensitively.
///
/// A single word matches on word boundaries so muting "cat" does not also hide
/// "category"; a phrase or anything with punctuation matches as a substring,
/// which is what a user typing "black friday" or "$TSLA" expects.
bool textMatchesMutedTerm(String text, String term) {
  final needle = term.trim();
  if (needle.isEmpty) {
    return false;
  }

  final haystack = text.toLowerCase();
  final lowered = needle.toLowerCase();
  final isSingleWord = !lowered.contains(' ') && lowered.split('').every(_wordCharacter.hasMatch);

  if (!isSingleWord) {
    return haystack.contains(lowered);
  }

  return RegExp('(?<![\\p{L}\\p{N}])${RegExp.escape(lowered)}(?![\\p{L}\\p{N}])', unicode: true)
      .hasMatch(haystack);
}

/// The text of a chain that keyword muting looks at: every post in the thread,
/// plus quoted text, since a muted word in a quote is still on screen.
String chainSearchText(TweetChain chain) {
  final parts = <String>[];
  for (final tweet in chain.tweets) {
    parts.add(tweet.fullText ?? tweet.text ?? '');
    final quoted = tweet.quotedStatusWithCard;
    if (quoted != null) {
      parts.add(quoted.fullText ?? quoted.text ?? '');
    }
  }
  return parts.join(' ');
}

bool _isSensitive(TweetChain chain) => chain.tweets.any((tweet) => tweet.possiblySensitive == true);

int chainLikes(TweetChain chain) => chain.tweets.firstOrNull?.favoriteCount ?? 0;

int chainRetweets(TweetChain chain) {
  final tweet = chain.tweets.firstOrNull;
  if (tweet == null) {
    return 0;
  }
  return (tweet.retweetCount ?? 0) + (tweet.quoteCount ?? 0);
}

/// Keeps only the chains a custom feed should show.
///
/// Thresholds read the thread's first post, the same post the popular sort
/// ranks by, so "at least 100 likes" means the same number the footer shows.
List<TweetChain> applyCustomFeedRules(List<TweetChain> chains, CustomFeedRules rules) {
  if (rules.isEmpty) {
    return chains;
  }

  return chains.where((chain) {
    switch (rules.contentFilter) {
      case contentFilterSfw:
        if (_isSensitive(chain)) return false;
      case contentFilterNsfw:
        if (!_isSensitive(chain)) return false;
      default:
        break;
    }

    if (rules.minLikes > 0 && chainLikes(chain) < rules.minLikes) {
      return false;
    }
    if (rules.minRetweets > 0 && chainRetweets(chain) < rules.minRetweets) {
      return false;
    }

    if (rules.mutedKeywords.isNotEmpty) {
      final text = chainSearchText(chain);
      if (rules.mutedKeywords.any((term) => textMatchesMutedTerm(text, term))) {
        return false;
      }
    }

    return true;
  }).toList(growable: false);
}
