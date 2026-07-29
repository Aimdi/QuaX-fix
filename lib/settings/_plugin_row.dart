import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/home/home_model.dart';
import 'package:xta/plugins/plugin.dart';
import 'package:xta/plugins/plugin_storage.dart';

/// A plugin on offer but not installed: what it does, and a button.
class AvailablePluginRow extends StatelessWidget {
  final XtaPlugin plugin;
  final VoidCallback onInstall;

  const AvailablePluginRow({super.key, required this.plugin, required this.onInstall});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(plugin.icon),
      title: Text(plugin.title(context)),
      subtitle: Text(plugin.description(context)),
      trailing: FilledButton.tonal(
        onPressed: onInstall,
        child: Text(L10n.of(context).plugin_install),
      ),
    );
  }
}

/// An installed plugin: what it is holding, its tab, its settings, and the way
/// back off the device.
class InstalledPluginRow extends StatelessWidget {
  final XtaPlugin plugin;
  final VoidCallback onUninstall;

  /// The tab switch and the settings screen both change what the parent should
  /// draw, and neither owns the list.
  final VoidCallback onChanged;

  const InstalledPluginRow({
    super.key,
    required this.plugin,
    required this.onUninstall,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = PrefService.of(context);
    final tabPref = plugin.homeTabPrefKey;
    final settings = plugin.settingsScreen(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(plugin.icon),
          title: Text(plugin.title(context)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plugin.description(context)),
              const SizedBox(height: 2),
              PluginFootprintText(plugin: plugin),
            ],
          ),
          trailing: TextButton(
            onPressed: onUninstall,
            child: Text(L10n.of(context).plugin_uninstall),
          ),
        ),
        // Plugins whose feature is reachable from the Groups tab as well can
        // give up their own tab.
        if (tabPref != null)
          SwitchListTile(
            secondary: const SizedBox(width: 24),
            title: Text(L10n.of(context).plugin_show_as_tab),
            subtitle: Text(L10n.of(context).plugin_show_as_tab_description),
            value: plugin.showsHomeTab(prefs),
            onChanged: (value) => _setShowsTab(context, prefs, tabPref, value),
          ),
        if (settings != null)
          ListTile(
            leading: const SizedBox(width: 24),
            title: Text(L10n.of(context).settings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => settings));
              onChanged();
            },
          ),
      ],
    );
  }

  Future<void> _setShowsTab(
    BuildContext context,
    BasePrefService prefs,
    String tabPref,
    bool value,
  ) async {
    await prefs.set(tabPref, value);

    // Asking for the tab back has to actually bring it back: the page list only
    // auto-selects a plugin tab it has never seeded, so that memory is cleared
    // here or the switch would turn on and nothing appear.
    if (value) {
      final seeded = prefs.getStringList(optionSeededPluginTabs) ?? const <String>[];
      await prefs.set(optionSeededPluginTabs, seeded.where((e) => e != plugin.id).toList());
    }

    if (!context.mounted) return;
    await context.read<HomeModel>().loadPages();
    onChanged();
  }
}

/// Reads what a plugin is holding on the device, once, when it is first shown.
class PluginFootprintText extends StatefulWidget {
  final XtaPlugin plugin;

  const PluginFootprintText({super.key, required this.plugin});

  @override
  State<PluginFootprintText> createState() => _PluginFootprintTextState();
}

class _PluginFootprintTextState extends State<PluginFootprintText> {
  PluginFootprint? _footprint;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final footprint = await widget.plugin.footprint();
    if (mounted) {
      setState(() => _footprint = footprint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final footprint = _footprint;
    final style = Theme.of(context).textTheme.bodySmall;

    // Nothing until the answer is in: a "0 items" that turns into a real number
    // reads as the plugin having just been filled.
    if (footprint == null) {
      return const SizedBox(height: 16);
    }

    if (footprint == emptyFootprint) {
      return Text(L10n.of(context).plugin_storage_empty, style: style);
    }

    return Text(
      L10n.of(context).plugin_storage_used('${footprint.items}', formatStorageSize(footprint.bytes)),
      style: style,
    );
  }
}
