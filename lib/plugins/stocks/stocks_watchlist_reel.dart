import 'package:flutter/material.dart';
import 'package:quax/plugins/stocks/stock_sparkline.dart';
import 'package:quax/plugins/stocks/stocks_format.dart';
import 'package:quax/tweet/ticker/ticker_quote.dart';

/// The card the reel is built from. Fixed, because a card that grew when its
/// quote arrived would shuffle every other card sideways under the finger.
const double kStockCardWidth = 132;
const double kStockCardHeight = 92;

/// The watchlist as a row of price cards, pinned above the list.
///
/// Quotes are passed in rather than fetched here: every card wants one, and a
/// strip that fetched its own would race the list showing the same symbols.
class StocksWatchlistReel extends StatelessWidget {
  final List<String> symbols;
  final Map<String, TickerQuote> quotes;

  const StocksWatchlistReel({super.key, required this.symbols, required this.quotes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kStockCardHeight + 16,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: symbols.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _StockCard(symbol: symbols[index], quote: quotes[symbols[index]]),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final String symbol;
  final TickerQuote? quote;

  const _StockCard({required this.symbol, this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaded = quote;

    return SizedBox(
      width: kStockCardWidth,
      height: kStockCardHeight,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openTicker(context, symbol),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700),
                ),
                _price(theme, loaded),
                _change(theme, loaded),
                const SizedBox(height: 4),
                Expanded(child: _sparkline(loaded)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _price(ThemeData theme, TickerQuote? quote) {
    final price = quote?.price ?? quote?.points.lastOrNull?.close;

    return Text(
      price == null ? kStockPlaceholder : stockMoneyFormat.format(price),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall!.copyWith(
        color: price == null ? theme.colorScheme.outline : theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _change(ThemeData theme, TickerQuote? quote) {
    final percent = quote?.changePercent;

    return Text(
      percent == null ? kStockPlaceholder : stockPercentLabel(percent),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall!.copyWith(
        fontWeight: FontWeight.w700,
        color: percent == null ? theme.colorScheme.outline : stockChangeColour(quote?.isUp),
      ),
    );
  }

  /// A flat rule while the quote is missing: the card keeps its shape, and no
  /// spinner blinks at the reader once per symbol.
  Widget _sparkline(TickerQuote? quote) {
    final closes = quote?.points.map((p) => p.close).toList(growable: false) ?? const <double>[];

    return StockSparkline(closes: closes, colour: stockChangeColour(quote?.isUp));
  }
}
