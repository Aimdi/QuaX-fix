import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/home/home_model.dart';
import 'package:xta/plugins/plugin.dart';
import 'package:xta/plugins/plugin_catalogue.dart';
import 'package:xta/plugins/plugin_registry.dart';
import 'package:xta/settings/_plugin_row.dart';

/// What the reader has installed, and what is on offer.
///
/// The offer comes from a document published in the app's repository, so a
/// plugin can be added or withdrawn without a release. It can only ever narrow
/// what this build already contains, and it never withdraws something already
/// installed.
///
/// Installing is what makes a plugin start keeping things on the device;
/// uninstalling takes them all back off.
class SettingsPluginStoreFragment extends StatefulWidget {
  const SettingsPluginStoreFragment({super.key});

  @override
  State<SettingsPluginStoreFragment> createState() => _SettingsPluginStoreFragmentState();
}

class _SettingsPluginStoreFragmentState extends State<SettingsPluginStoreFragment> {
  late final PluginCatalogue _catalogue = PluginCatalogue(PrefService.of(context, listen: false));

  List<String> _offered = const [];
  bool _loading = true;
  bool _unreachable = false;

  @override
  void initState() {
    super.initState();
    // Until a catalogue has ever been read, everything compiled in is on offer.
    // A published file that is missing, or a device that has never been online,
    // must not leave the store empty — the plugins are in the build either way.
    _offered = _catalogue.hasCache ? _catalogue.cached() : builtInPlugins.map((p) => p.id).toList();

    // After the first frame: what is already known is what the reader sees
    // while the published list is on its way.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final fetched = await _catalogue.fetch();
    if (!mounted) return;

    setState(() {
      _loading = false;
      _unreachable = fetched == null;
      if (fetched != null) {
        _offered = fetched;
      }
    });
  }

  /// Installed plugins are listed whatever the catalogue currently says: one
  /// that has been withdrawn still has the reader's data in it, and they need a
  /// way to get it back off.
  List<XtaPlugin> get _installed {
    final prefs = PrefService.of(context, listen: false);
    return builtInPlugins.where((plugin) => plugin.isEnabled(prefs)).toList();
  }

  List<XtaPlugin> get _available {
    final prefs = PrefService.of(context, listen: false);
    return builtInPlugins
        .where((plugin) => !plugin.isEnabled(prefs) && _offered.contains(plugin.id))
        .toList();
  }

  Future<void> _install(XtaPlugin plugin) async {
    final prefs = PrefService.of(context, listen: false);
    await plugin.setEnabled(prefs, true);
    if (!mounted) return;
    await context.read<HomeModel>().loadPages();
    if (mounted) setState(() {});
  }

  /// Uninstalling deletes what the plugin saved, so it is asked about first.
  Future<void> _uninstall(XtaPlugin plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = L10n.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.plugin_uninstall_confirm(plugin.title(dialogContext))),
          content: Text(l10n.plugin_uninstall_confirm_detail),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.plugin_uninstall),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await plugin.uninstall(context);
    if (!mounted) return;
    await context.read<HomeModel>().loadPages();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final installed = _installed;
    final available = _available;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_store),
        actions: [
          IconButton(
            tooltip: l10n.retry,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_unreachable)
              ListTile(
                leading: const Icon(Icons.cloud_off),
                title: Text(l10n.plugin_catalogue_unavailable),
                // Only where it is true: on a first run with nothing cached
                // there is no older list being shown.
                subtitle: _catalogue.hasCache ? Text(l10n.plugin_catalogue_cached) : null,
              ),
            if (installed.isNotEmpty) ...[
              _header(context, l10n.plugin_installed),
              for (final plugin in installed)
                InstalledPluginRow(
                  plugin: plugin,
                  onUninstall: () => _uninstall(plugin),
                  onChanged: () => setState(() {}),
                ),
            ],
            if (available.isNotEmpty) ...[
              _header(context, l10n.plugin_available),
              for (final plugin in available)
                AvailablePluginRow(plugin: plugin, onInstall: () => _install(plugin)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelLarge!
              .copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );
}
