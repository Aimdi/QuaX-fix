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
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final plugin = builtInPlugins[index];
          final enabled = plugin.isEnabled(prefs);
          return SwitchListTile(
            secondary: Icon(plugin.icon),
            title: Text(plugin.title(context)),
            subtitle: Text(plugin.description(context)),
            value: enabled,
            onChanged: (value) async {
              await plugin.setEnabled(prefs, value);
              if (!mounted) return;
              await context.read<HomeModel>().loadPages();
              setState(() {});
            },
          );
        },
      ),
    );
  }
}
