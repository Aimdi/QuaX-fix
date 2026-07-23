import 'package:quax/plugins/plugin.dart';
import 'package:quax/plugins/substack/substack_plugin.dart';

/// Built-in plugins shipped with QuaX.
final List<QuaxPlugin> builtInPlugins = [
  const SubstackPlugin(),
];

QuaxPlugin? pluginById(String id) {
  for (final plugin in builtInPlugins) {
    if (plugin.id == id) return plugin;
  }
  return null;
}
