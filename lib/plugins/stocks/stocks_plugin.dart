import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/plugins/plugin.dart';
import 'package:quax/plugins/stocks/stocks_screen.dart';
import 'package:quax/plugins/stocks/stocks_store.dart';

/// A watchlist of tickers, read-only like everything else here: quotes are
/// shown, nothing is traded.
class StocksPlugin extends QuaxPlugin {
  StocksPlugin();

  @override
  String get id => pluginIdStocks;

  @override
  String get enabledPrefKey => optionPluginStocksEnabled;

  @override
  IconData get icon => Icons.show_chart;

  @override
  String? get homeTabPrefKey => optionPluginStocksShowTab;

  @override
  String title(BuildContext context) => L10n.of(context).plugin_stocks_title;

  @override
  String description(BuildContext context) => L10n.of(context).plugin_stocks_description;

  @override
  NavigationPage homePage(BuildContext context) {
    return NavigationPage(
      pluginIdStocks,
      (c) => L10n.of(c).plugin_stocks_title,
      const Icon(Icons.show_chart),
      const Icon(Icons.show_chart),
    );
  }

  @override
  Widget homeScreen({required ScrollController scrollController}) {
    return StocksScreen(scrollController: scrollController);
  }

  @override
  List<String> get tables => const [tableStockSubscription];

  @override
  Future<void> forgetLoadedData(BuildContext context) async {
    await context.read<StocksWatchlistStore>().load();
  }
}
