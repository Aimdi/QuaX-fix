/// A symbol's recent price history.
///
/// Parsed out of a chart endpoint whose shape, like X's, is not promised to
/// anyone — so every field is read defensively and a payload that no longer
/// fits yields null rather than throwing inside a screen.
library;

class TickerPoint {
  final DateTime at;
  final double close;

  const TickerPoint({required this.at, required this.close});
}

class TickerQuote {
  final String symbol;
  final String? currency;

  /// The latest price, and the close it is measured against. Either may be
  /// absent — a symbol can return history with no live quote attached.
  final double? price;
  final double? previousClose;

  /// What the rest of the market page is made of: how much changed hands, and
  /// where today sits inside the year. All optional — the chart endpoint only
  /// carries them for symbols it has them for.
  final double? volume;
  final double? yearHigh;
  final double? yearLow;

  final List<TickerPoint> points;

  const TickerQuote({
    required this.symbol,
    required this.currency,
    required this.price,
    required this.previousClose,
    required this.points,
    this.volume,
    this.yearHigh,
    this.yearLow,
  });

  double? get change {
    final now = price ?? points.lastOrNull?.close;
    final before = previousClose;
    if (now == null || before == null) {
      return null;
    }
    return now - before;
  }

  double? get changePercent {
    final delta = change;
    final before = previousClose;
    if (delta == null || before == null || before == 0) {
      return null;
    }
    return delta / before * 100;
  }

  /// True when the symbol is up on the day. Null when there is nothing to
  /// compare against, which is not the same as flat.
  bool? get isUp {
    final delta = change;
    return delta == null ? null : delta >= 0;
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return value is String ? double.tryParse(value) : null;
  }

  /// Reads the `chart.result[0]` shape: a list of timestamps alongside a
  /// parallel list of closes, plus a `meta` block.
  ///
  /// Gaps are expected — a market holiday leaves a null close against a real
  /// timestamp — so points are only kept where both halves are present.
  static TickerQuote? fromChartJson(Object? json, {required String symbol}) {
    if (json is! Map) {
      return null;
    }

    final results = (json['chart'] is Map) ? (json['chart'] as Map)['result'] : null;
    if (results is! List || results.isEmpty) {
      return null;
    }

    final result = results.first;
    if (result is! Map) {
      return null;
    }

    final meta = result['meta'] is Map ? result['meta'] as Map : const {};
    final timestamps = result['timestamp'];

    final indicators = result['indicators'];
    final quotes = indicators is Map ? indicators['quote'] : null;
    final quote = (quotes is List && quotes.isNotEmpty && quotes.first is Map) ? quotes.first as Map : const {};
    final closes = quote['close'];

    final points = <TickerPoint>[];
    if (timestamps is List && closes is List) {
      for (var i = 0; i < timestamps.length && i < closes.length; i++) {
        final seconds = timestamps[i];
        final close = _toDouble(closes[i]);
        if (seconds is! num || close == null) {
          continue;
        }
        points.add(TickerPoint(
          at: DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000, isUtc: true).toLocal(),
          close: close,
        ));
      }
    }

    if (points.isEmpty) {
      return null;
    }

    return TickerQuote(
      symbol: (meta['symbol'] as String?) ?? symbol,
      currency: meta['currency'] as String?,
      price: _toDouble(meta['regularMarketPrice']),
      previousClose: _toDouble(meta['chartPreviousClose']) ?? _toDouble(meta['previousClose']),
      points: points,
      volume: _toDouble(meta['regularMarketVolume']),
      yearHigh: _toDouble(meta['fiftyTwoWeekHigh']),
      yearLow: _toDouble(meta['fiftyTwoWeekLow']),
    );
  }
}
