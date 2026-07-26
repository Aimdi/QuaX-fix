import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quax/tweet/ticker/ticker_quote.dart';

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
  static const userAgent = 'Mozilla/5.0 (Android) QuaX';

  static Uri chartUri(String symbol, {String range = '1mo', String interval = '1d'}) {
    return Uri.https(_host, '/v8/finance/chart/${Uri.encodeComponent(symbol.toUpperCase())}', {
      'range': range,
      'interval': interval,
    });
  }

  Future<TickerQuote> fetchQuote(String symbol, {String range = '1mo', String interval = '1d'}) async {
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
