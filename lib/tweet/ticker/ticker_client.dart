import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xta/tweet/ticker/ticker_quote.dart';

enum TickerErrorKind { notFound, unavailable, badResponse }

class TickerException implements Exception {
  final TickerErrorKind kind;
  final String message;

  TickerException(this.kind, this.message);

  @override
  String toString() => 'TickerException{$kind: $message}';
}

/// Price history for a symbol.
///
/// The endpoint is public and needs no key or account, which is the only
/// reason it is here: a chart is not worth handing anyone a login for. Like
/// X's, it is undocumented, so [TickerQuote.fromChartJson] treats every field
/// as optional and this class turns a refusal into a typed error rather than
/// letting a screen show a stack trace.
class TickerClient {
  final http.Client httpClient;

  TickerClient({http.Client? httpClient}) : httpClient = httpClient ?? http.Client();

  static const _host = 'query1.finance.yahoo.com';
  static const _timeout = Duration(seconds: 15);

  /// A browser-ish agent: the host refuses an empty one outright.
  static const userAgent = 'Mozilla/5.0 (Android) XTA';

  /// Indices and a few well-known names are spoken as one thing and quoted as
  /// another: `$SPX` is `^GSPC` to the price service, `$DAX` is `^GDAXI`.
  static const _aliases = {
    'SPX': '^GSPC',
    'SP500': '^GSPC',
    'DJI': '^DJI',
    'DOW': '^DJI',
    'NDX': '^NDX',
    'IXIC': '^IXIC',
    'NASDAQ': '^IXIC',
    'RUT': '^RUT',
    'VIX': '^VIX',
    'DAX': '^GDAXI',
    'FTSE': '^FTSE',
    'CAC': '^FCHI',
    'N225': '^N225',
    'NIKKEI': '^N225',
    'HSI': '^HSI',
  };

  /// Every name to try for a cashtag, in order.
  ///
  /// A cashtag is written the way people say it — `$BTC`, `$SPX` — and the
  /// price service wants `BTC-USD` and `^GSPC`. Asking for the spoken form and
  /// giving up is why a crypto or index ticker charted as "no data" while an
  /// ordinary share worked fine.
  static List<String> candidatesFor(String symbol) {
    final upper = symbol.toUpperCase().trim();
    final alias = _aliases[upper];

    return <String>[
      upper,
      if (alias != null) alias,
      // Crypto is quoted as a pair. Harmless for a share: it simply 404s and
      // the real error from the first attempt is what surfaces.
      if (!upper.contains('-') && !upper.startsWith('^')) '$upper-USD',
    ];
  }

  static Uri chartUri(String symbol, {String range = '1mo', String interval = '1d'}) {
    return Uri.https(_host, '/v8/finance/chart/${Uri.encodeComponent(symbol.toUpperCase())}', {
      'range': range,
      'interval': interval,
    });
  }

  /// The first name that answers with a price history.
  ///
  /// Only a "there is no such symbol" answer moves on to the next candidate: a
  /// timeout or a refusal says nothing about the name, and trying two more
  /// would just make the reader wait three times as long for the same failure.
  Future<TickerQuote> fetchQuote(String symbol, {String range = '1mo', String interval = '1d'}) async {
    TickerException? last;

    for (final candidate in candidatesFor(symbol)) {
      try {
        return await _fetchOne(candidate, range: range, interval: interval);
      } on TickerException catch (e) {
        last = e;
        if (e.kind == TickerErrorKind.unavailable) {
          rethrow;
        }
      }
    }

    throw last ?? TickerException(TickerErrorKind.notFound, 'No such symbol: $symbol');
  }

  Future<TickerQuote> _fetchOne(String symbol, {required String range, required String interval}) async {
    final uri = chartUri(symbol, range: range, interval: interval);

    late http.Response response;
    try {
      response = await httpClient.get(uri, headers: {'User-Agent': userAgent}).timeout(_timeout);
    } catch (e) {
      throw TickerException(TickerErrorKind.unavailable, 'Could not reach the price service: $e');
    }

    if (response.statusCode == 404) {
      throw TickerException(TickerErrorKind.notFound, 'No such symbol: $symbol');
    }
    if (response.statusCode != 200) {
      throw TickerException(TickerErrorKind.unavailable, 'HTTP ${response.statusCode} for $symbol');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw TickerException(TickerErrorKind.badResponse, 'Response was not JSON: $e');
    }

    final quote = TickerQuote.fromChartJson(decoded, symbol: symbol);
    if (quote == null) {
      throw TickerException(TickerErrorKind.badResponse, 'No price history in the response for $symbol');
    }

    return quote;
  }
}
