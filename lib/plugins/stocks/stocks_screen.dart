import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/stocks/stocks_card.dart';
import 'package:xta/plugins/stocks/stocks_format.dart';
import 'package:xta/plugins/stocks/stocks_store.dart';
import 'package:xta/plugins/stocks/stocks_watchlist_reel.dart';
import 'package:xta/tweet/ticker/ticker_client.dart';
import 'package:xta/tweet/ticker/ticker_quote.dart';
import 'package:xta/ui/errors.dart';

/// The watchlist: a strip of price cards over the same symbols in full.
///
/// The symbols come from [StocksWatchlistStore] — they outlive the screen and
/// the manage sheet edits them too. The quotes do not: they are one screen's
/// view of a public price service, thrown away with it, so they live in [State]
/// rather than pretending to be app state.
class StocksScreen extends StatefulWidget {
  final ScrollController scrollController;

  const StocksScreen({super.key, required this.scrollController});

  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  final TickerClient _client = TickerClient();
  final Map<String, TickerQuote> _quotes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<StocksWatchlistStore>().load();
      if (mounted) {
        await _refreshQuotes();
      }
    });
  }

  Future<void> _refreshAll() async {
    await context.read<StocksWatchlistStore>().load();
    if (mounted) {
      await _refreshQuotes();
    }
  }

  /// Every symbol at once, and a symbol that fails keeps whatever it had.
  ///
  /// One name the price service has never heard of used to be enough to leave
  /// the whole watchlist blank; here it costs that one card its numbers.
  Future<void> _refreshQuotes() async {
    final symbols = context.read<StocksWatchlistStore>().state;
    final fetched = await Future.wait(symbols.map(_fetchQuote));
    if (!mounted) return;

    setState(() {
      _quotes
        ..removeWhere((symbol, _) => !symbols.contains(symbol))
        ..addEntries(fetched.nonNulls);
    });
  }

  Future<MapEntry<String, TickerQuote>?> _fetchQuote(String symbol) async {
    try {
      return MapEntry(symbol, await _client.fetchQuote(symbol));
    } on TickerException {
      return null;
    }
  }

  Future<String?> _askForSymbol() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = L10n.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.plugin_stocks_add),
          content: TextField(
            controller: controller,
            autofocus: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'AAPL'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSymbol() async {
    final entered = await _askForSymbol();
    if (entered == null || entered.isEmpty || !mounted) return;

    final symbol = StocksWatchlistStore.normaliseTicker(entered);
    if (symbol == null) {
      showSnackBar(context, icon: '⚠️', message: L10n.of(context).plugin_stocks_error);
      return;
    }

    await context.read<StocksWatchlistStore>().add(symbol);
    if (mounted) {
      await _refreshQuotes();
    }
  }

  Future<void> _remove(String symbol) async {
    await context.read<StocksWatchlistStore>().remove(symbol);
    if (mounted) {
      setState(() => _quotes.remove(symbol));
    }
  }

  Future<void> _manageWatchlist() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final store = sheetContext.read<StocksWatchlistStore>();
        return SafeArea(
          child: ScopedBuilder<StocksWatchlistStore, List<String>>(
            store: store,
            onState: (_, symbols) => ListView(
              shrinkWrap: true,
              children: [
                for (final symbol in symbols)
                  ListTile(
                    title: Text('\$$symbol'),
                    trailing: IconButton(
                      tooltip: L10n.of(sheetContext).unsubscribe,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(symbol),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final store = context.read<StocksWatchlistStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_stocks_title),
        actions: [
          IconButton(tooltip: l10n.plugin_stocks_add, icon: const Icon(Icons.add), onPressed: _addSymbol),
          IconButton(tooltip: l10n.plugin_stocks_watchlist, icon: const Icon(Icons.list), onPressed: _manageWatchlist),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ScopedBuilder<StocksWatchlistStore, List<String>>(
          store: store,
          onError: (_, error) => FullPageErrorWidget(
            error: error,
            stackTrace: null,
            // Names what failed to load rather than reusing the "not a ticker"
            // sentence, which would be the wrong reason for a storage failure.
            prefix: l10n.plugin_stocks_watchlist,
            onRetry: store.load,
          ),
          onLoading: (_) => const Center(child: CircularProgressIndicator()),
          onState: (context, symbols) => symbols.isEmpty ? _empty(context, l10n) : _watchlist(symbols),
        ),
      ),
    );
  }

  Widget _watchlist(List<String> symbols) {
    return Column(
      children: [
        StocksWatchlistReel(symbols: symbols, quotes: _quotes),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: symbols.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _dismissibleRow(symbols[index]),
          ),
        ),
      ],
    );
  }

  Widget _dismissibleRow(String symbol) {
    return Dismissible(
      key: ValueKey(symbol),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(symbol),
      background: Container(
        alignment: Alignment.centerRight,
        color: kStockDownColour,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: StockCard(symbol: symbol, quote: _quotes[symbol]),
    );
  }

  Widget _empty(BuildContext context, L10n l10n) {
    return ListView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
      children: [
        Icon(Icons.show_chart, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(l10n.plugin_stocks_empty, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: _addSymbol,
            icon: const Icon(Icons.add),
            label: Text(l10n.plugin_stocks_add),
          ),
        ),
      ],
    );
  }
}
