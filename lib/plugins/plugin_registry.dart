import 'package:xta/plugins/deepmarks/deepmarks_plugin.dart';
import 'package:xta/plugins/immich/immich_plugin.dart';
import 'package:xta/plugins/karakeep/karakeep_plugin.dart';
import 'package:xta/plugins/plugin.dart';
import 'package:xta/plugins/reddit/reddit_plugin.dart';
import 'package:xta/plugins/stocks/stocks_plugin.dart';
import 'package:xta/plugins/substack/substack_plugin.dart';
import 'package:xta/plugins/threads/threads_plugin.dart';

/// Built-in plugins shipped with XTA.
final List<XtaPlugin> builtInPlugins = [
  SubstackPlugin(),
  KarakeepPlugin(),
  DeepmarksPlugin(),
  ImmichPlugin(),
  RedditPlugin(),
  StocksPlugin(),
  ThreadsPlugin(),
];

XtaPlugin? pluginById(String id) {
  for (final plugin in builtInPlugins) {
    if (plugin.id == id) return plugin;
  }
  return null;
}
