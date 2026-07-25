import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/home_model.dart';
import 'package:quax/plugins/plugin_registry.dart';

/// Lists built-in plugins and lets the user enable / disable them.
class SettingsPluginStoreFragment extends StatefulWidget {
  const SettingsPluginStoreFragment({super.key});

  @override
  State<SettingsPluginStoreFragment> createState() => _SettingsPluginStoreFragmentState();
}

class _SettingsPluginStoreFragmentState extends State<SettingsPluginStoreFragment> {
  @override
  Widget build(BuildContext context) {
    final prefs = PrefService.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).plugin_store)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: builtInPlugins.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final plugin = builtInPlugins[index];
          final enabled = plugin.isEnabled(prefs);
          final tabPref = plugin.homeTabPrefKey;

          final row = SwitchListTile(
            secondary: Icon(plugin.icon),
            title: Text(plugin.title(context)),
            subtitle: Text(plugin.description(context)),
            value: enabled,
            onChanged: (value) async {
              await plugin.setEnabled(prefs, value);
              if (!context.mounted) return;
              await context.read<HomeModel>().loadPages();
              setState(() {});
            },
          );

          if (tabPref == null) {
            return row;
          }

          // Plugins whose feature is reachable from the Groups tab as well can
          // give up their own tab.
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row,
              SwitchListTile(
                secondary: const SizedBox(width: 24),
                title: Text(L10n.of(context).plugin_show_as_tab),
                subtitle: Text(L10n.of(context).plugin_show_as_tab_description),
                value: plugin.showsHomeTab(prefs),
                onChanged: enabled
                    ? (value) async {
                        await prefs.set(tabPref, value);
                        if (!context.mounted) return;
                        await context.read<HomeModel>().loadPages();
                        setState(() {});
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
