import 'package:flutter/material.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/stocks/stock_sparkline.dart';
import 'package:xta/plugins/stocks/stocks_format.dart';
import 'package:xta/tweet/ticker/ticker_quote.dart';
import 'package:xta/tweet/ticker/ticker_stats.dart';

/// One watched symbol, the size a market page gives it.
///
/// A row of small print says only that the symbol is still on the list. What a
/// reader actually opens a watchlist for is the shape of the day and where it
/// sits in the year, so the card carries the price large, the move beside it,
/// the line under it against the previous close, and the year's range below
/// that — the same reading StockTwits gives a symbol.
class StockCard extends StatelessWidget {
  final String symbol;
  final TickerQuote? quote;

  const StockCard({super.key, required this.symbol, required this.quote});

  static const double _sparklineHeight = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaded = quote;

    return InkWell(
      onTap: () => openTicker(context, symbol),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, theme),
            const SizedBox(height: 8),
            SizedBox(height: _sparklineHeight, child: _sparkline()),
            const SizedBox(height: 8),
            if (loaded != null) TickerStats(quote: loaded),
          ],
        ),
      ),
    );
  }

  /// Symbol on the left, price and today's move on the right.
  Widget _header(BuildContext context, ThemeData theme) {
    final l10n = L10n.of(context);
    final price = quote?.price ?? quote?.points.lastOrNull?.close;
    final change = quote?.change;
    final percent = quote?.changePercent;
    final colour = change == null ? theme.colorScheme.outline : stockChangeColour(quote?.isUp);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$$symbol',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                price == null ? kStockPlaceholder : stockMoneyFormat.format(price),
                style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              change == null ? kStockPlaceholder : stockChangeLabel(change),
              style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: colour),
            ),
            Text(
              percent == null ? kStockPlaceholder : stockPercentLabel(percent),
              style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: colour),
            ),
            Text(l10n.plugin_stocks_today, style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }

  Widget _sparkline() {
    final closes = quote?.points.map((p) => p.close).toList(growable: false) ?? const <double>[];

    return StockSparkline(
      closes: closes,
      baseline: quote?.previousClose,
      colour: stockChangeColour(quote?.isUp),
      strokeWidth: 2,
      filled: true,
    );
  }
}
