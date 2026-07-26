import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pref/pref.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/ticker/ticker_chart.dart';
import 'package:quax/tweet/ticker/ticker_client.dart';
import 'package:quax/tweet/ticker/ticker_quote.dart';
import 'package:quax/tweet/tweet_context_scope.dart';

class TickerScreenArguments {
  /// The ticker without its `$`, e.g. `AAPL`.
  final String symbol;

  TickerScreenArguments({required this.symbol});

  @override
  String toString() => 'TickerScreenArguments{symbol: $symbol}';
}

/// A ticker: what the symbol has done lately, and the posts talking about it.
///
/// The chart is drawn from price data QuaX fetches itself rather than embedded
/// from anyone — no third-party page, no scripts, nothing that could carry a
/// tracker into the app. The price service is still an outside request though,
/// so it has a switch, and with it off the posts work exactly as before.
class TickerScreen extends StatelessWidget {
  const TickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as TickerScreenArguments;
    return _TickerScreen(symbol: args.symbol);
  }
}

class _TickerScreen extends StatefulWidget {
  final String symbol;

  const _TickerScreen({required this.symbol});

  @override
  State<_TickerScreen> createState() => _TickerScreenState();
}

class _TickerScreenState extends State<_TickerScreen> {
  final TweetFeedController _feed = TweetFeedController();
  final TickerClient _client = TickerClient();

  TickerQuote? _quote;
  bool _quoteFailed = false;
  bool _loadingQuote = false;

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_quote == null && !_quoteFailed && !_loadingQuote && _chartEnabled) {
      _loadQuote();
    }
  }

  bool get _chartEnabled => PrefService.of(context).get<bool>(optionTickerChart) == true;

  Future<void> _loadQuote() async {
    setState(() => _loadingQuote = true);
    try {
      final quote = await _client.fetchQuote(widget.symbol);
      if (mounted) {
        setState(() {
          _quote = quote;
          _loadingQuote = false;
        });
      }
    } on TickerException {
      // A missing price is not worth an error screen: the posts below are the
      // reason the ticker was tapped, and they are unaffected.
      if (mounted) {
        setState(() {
          _quoteFailed = true;
          _loadingQuote = false;
        });
      }
    }
  }

  Future<TweetPageResult> _loadPage(String? cursor) async {
    final result = await Twitter.searchTweets('\$${widget.symbol}', true, cursor: cursor);
    return (chains: result.chains, nextCursor: result.cursorBottom);
  }

  Widget _quoteHeader(BuildContext context, TickerQuote quote) {
    final theme = Theme.of(context);
    final price = quote.price ?? quote.points.last.close;
    final percent = quote.changePercent;
    final up = quote.isUp ?? true;
    final money = NumberFormat.decimalPatternDigits(decimalDigits: 2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(money.format(price), style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700)),
          if (quote.currency != null) ...[
            const SizedBox(width: 4),
            Text(quote.currency!, style: theme.textTheme.bodySmall),
          ],
          const Spacer(),
          if (percent != null)
            Text(
              '${up ? '+' : ''}${percent.toStringAsFixed(2)}%',
              style: theme.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: up ? const Color(0xFF00BA7C) : const Color(0xFFF4212E),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _chartSection(BuildContext context) {
    if (!_chartEnabled || _quoteFailed) {
      return null;
    }

    final quote = _quote;
    if (quote == null) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _quoteHeader(context, quote),
        const SizedBox(height: 8),
        TickerChart(quote: quote),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chartSection(context);

    return Scaffold(
      appBar: AppBar(title: Text('\$${widget.symbol.toUpperCase()}')),
      body: Column(
        children: [
          if (chart != null) chart,
          Expanded(
            child: TweetContextScope(
              child: PaginatedTweetList(
                feed: _feed,
                loadPage: _loadPage,
                username: null,
                firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets,
                newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
                emptyMessage: L10n.of(context).no_posts_match_your_search,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
