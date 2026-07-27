/// How the BPC plugin opens a paywalled article inside QuaX.
///
/// The Chrome extension rewrites headers, blocks paywall scripts, and injects
/// content scripts. None of that exists in a Flutter WebView, so each strategy
/// is a mobile-friendly stand-in that still unlocks a useful share of sites.
enum BpcStrategy {
  /// Open the article through archive.ph (search / latest snapshot).
  archive,

  /// Open through the 12ft.io proxy.
  twelveFt,

  /// Load the original URL in a WebView that identifies as Googlebot.
  googlebot,
}

BpcStrategy parseBpcStrategy(String? raw) {
  return switch (raw) {
    'twelve_ft' => BpcStrategy.twelveFt,
    'googlebot' => BpcStrategy.googlebot,
    _ => BpcStrategy.archive,
  };
}

String bpcStrategyPrefValue(BpcStrategy strategy) {
  return switch (strategy) {
    BpcStrategy.archive => 'archive',
    BpcStrategy.twelveFt => 'twelve_ft',
    BpcStrategy.googlebot => 'googlebot',
  };
}

/// Build the URL the in-app reader should load for [articleUrl].
Uri bpcReaderUri(String articleUrl, BpcStrategy strategy) {
  final cleaned = articleUrl.trim();
  return switch (strategy) {
    BpcStrategy.archive => Uri.https('archive.ph', '/', {'url': cleaned}),
    BpcStrategy.twelveFt => Uri.parse('https://12ft.io/$cleaned'),
    BpcStrategy.googlebot => Uri.parse(cleaned),
  };
}

/// User-Agent used when [BpcStrategy.googlebot] loads the original site.
const bpcGooglebotUserAgent =
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
