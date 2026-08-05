import 'package:flutter_test/flutter_test.dart';
import 'package:xta/plugins/plugin_brand.dart';
import 'package:xta/plugins/plugin_category.dart';
import 'package:xta/plugins/plugin_registry.dart';

void main() {
  test('every built-in plugin has a store category', () {
    for (final plugin in builtInPlugins) {
      expect(pluginCategoryOrder, contains(plugin.category), reason: plugin.id);
    }
  });

  test('the store groups plugins under reading, markets, bookmarks and media', () {
    final groups = groupPluginsByCategory(builtInPlugins);
    expect(groups.map((g) => g.category), [
      PluginCategory.reading,
      PluginCategory.markets,
      PluginCategory.bookmarks,
      PluginCategory.media,
    ]);
    expect(groups.first.plugins.map((p) => p.id), containsAll(['reddit', 'substack', 'threads']));
    expect(groups[1].plugins.single.id, 'stocks');
  });
}
