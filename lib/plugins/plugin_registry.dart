import 'package:quax/plugins/deepmarks/deepmarks_plugin.dart';
import 'package:quax/plugins/karakeep/karakeep_plugin.dart';
import 'package:quax/plugins/plugin.dart';
import 'package:quax/plugins/reddit/reddit_plugin.dart';
import 'package:quax/plugins/stocks/stocks_plugin.dart';
import 'package:quax/plugins/substack/substack_plugin.dart';

/// Built-in plugins shipped with QuaX.
final List<QuaxPlugin> builtInPlugins = [
  SubstackPlugin(),
  KarakeepPlugin(),
  DeepmarksPlugin(),
  RedditPlugin(),
  StocksPlugin(),
];

QuaxPlugin? pluginById(String id) {
  for (final plugin in builtInPlugins) {
    if (plugin.id == id) return plugin;
  }
  return null;
}
