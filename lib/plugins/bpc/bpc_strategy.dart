/// How the BPC plugin opens a paywalled article inside QuaX.
enum BpcStrategy {
  /// Run BPC's tactics inside the app: block paywall scripts, set bot headers,
  /// clear cookies when the rule asks, and inject an unhide script.
  inApp,

  /// Open the article through archive.ph (search / latest snapshot).
  archive,

  /// Open through the 12ft.io proxy.
  twelveFt,

  /// Load the original URL identifying as Googlebot, with no other rule work.
  googlebot,
}

BpcStrategy parseBpcStrategy(String? raw) {
  return switch (raw) {
    'archive' => BpcStrategy.archive,
    'twelve_ft' => BpcStrategy.twelveFt,
    'googlebot' => BpcStrategy.googlebot,
    // Older installs defaulted to archive before the in-app engine existed.
    'in_app' || null || '' => BpcStrategy.inApp,
    _ => BpcStrategy.inApp,
  };
}

String bpcStrategyPrefValue(BpcStrategy strategy) {
  return switch (strategy) {
    BpcStrategy.inApp => 'in_app',
    BpcStrategy.archive => 'archive',
    BpcStrategy.twelveFt => 'twelve_ft',
    BpcStrategy.googlebot => 'googlebot',
  };
}

/// Build the URL the reader should navigate to for proxy strategies.
///
/// [BpcStrategy.inApp] and [BpcStrategy.googlebot] load [articleUrl] itself.
Uri bpcReaderUri(String articleUrl, BpcStrategy strategy) {
  final cleaned = articleUrl.trim();
  return switch (strategy) {
    BpcStrategy.inApp || BpcStrategy.googlebot => Uri.parse(cleaned),
    BpcStrategy.archive => Uri.https('archive.ph', '/', {'url': cleaned}),
    BpcStrategy.twelveFt => Uri.parse('https://12ft.io/$cleaned'),
  };
}

/// User-Agent used when a rule (or the googlebot strategy) asks for Googlebot.
const bpcGooglebotUserAgent =
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';

/// Referer many googlebot rules expect.
const bpcGoogleReferer = 'https://www.google.com/';
