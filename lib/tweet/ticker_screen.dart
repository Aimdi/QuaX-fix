import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/tweet_context_scope.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TickerScreenArguments {
  /// The ticker without its `$`, e.g. `AAPL`.
  final String symbol;

  TickerScreenArguments({required this.symbol});

  @override
  String toString() => 'TickerScreenArguments{symbol: $symbol}';
}

/// The chart TradingView serves for a symbol.
///
/// Kept as a plain function so the URL is written in one place and can be
/// checked without a WebView.
Uri tradingViewChartUrl(String symbol, {required bool dark}) {
  return Uri.https('s.tradingview.com', '/widgetembed/', {
    'symbol': symbol.toUpperCase(),
    'interval': 'D',
    'theme': dark ? 'dark' : 'light',
    'style': '1',
    'hide_side_toolbar': '1',
    'hide_legend': '0',
    'withdateranges': '1',
    'saveimage': '0',
  });
}

/// A ticker: the chart, and the posts talking about it.
///
/// The chart is the one thing in QuaX that loads from somewhere other than X.
/// It is a TradingView embed, so opening this screen tells TradingView which
/// symbol was asked for — which is why it has a switch of its own, and why the
/// posts below it work perfectly well with the chart turned off.
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
  WebViewController? _chart;

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  Future<TweetPageResult> _loadPage(String? cursor) async {
    final result = await Twitter.searchTweets('\$${widget.symbol}', true, cursor: cursor);
    return (chains: result.chains, nextCursor: result.cursorBottom);
  }

  /// Built on first paint rather than in initState: the chart follows the
  /// theme, which is not readable until the widget has a context.
  WebViewController _chartController(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return _chart ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Theme.of(context).scaffoldBackgroundColor)
      ..loadRequest(tradingViewChartUrl(widget.symbol, dark: dark));
  }

  @override
  Widget build(BuildContext context) {
    final showChart = PrefService.of(context).get<bool>(optionTickerChart) == true;

    return Scaffold(
      appBar: AppBar(title: Text('\$${widget.symbol.toUpperCase()}')),
      body: Column(
        children: [
          if (showChart)
            SizedBox(
              height: 320,
              child: WebViewWidget(controller: _chartController(context)),
            ),
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
