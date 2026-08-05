import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/home/home_model.dart';
import 'package:xta/plugins/plugin.dart';
import 'package:xta/plugins/plugin_catalogue.dart';
import 'package:xta/plugins/plugin_brand.dart';
import 'package:xta/plugins/plugin_category.dart';
import 'package:xta/plugins/plugin_registry.dart';
import 'package:xta/settings/_plugin_row.dart';

/// What the reader has installed, and what is on offer — grouped by what each
/// plugin is for (reading, markets, bookmarks, media) rather than a flat list.
///
/// The offer comes from a document published in the app's repository, so a
/// plugin can be added or withdrawn without a release. It can only ever narrow
/// what this build already contains, and it never withdraws something already
/// installed.
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
    _offered = _catalogue.hasCache ? _catalogue.cached() : builtInPlugins.map((p) => p.id).toList();
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

  /// Visible in the store: installed always, plus anything the catalogue still
  /// offers. Installed-but-withdrawn plugins stay so the reader can uninstall.
  /// Private plugins only appear when show-private is on (or already installed).
  List<XtaPlugin> get _listed {
    final prefs = PrefService.of(context, listen: false);
    final showPrivate = prefs.get<bool>(optionPluginStoreShowPrivate) == true;
    return builtInPlugins
        .where((plugin) =>
            plugin.isEnabled(prefs) ||
            _offered.contains(plugin.id) ||
            (plugin.isPrivate && showPrivate))
        .toList();
  }

  Future<void> _install(XtaPlugin plugin) async {
    final prefs = PrefService.of(context, listen: false);
    await plugin.setEnabled(prefs, true);
    if (!mounted) return;
    await context.read<HomeModel>().loadPages();
    if (mounted) setState(() {});
  }

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
    final prefs = PrefService.of(context, listen: false);
    final groups = groupPluginsByCategory(_listed);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_store),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'private') {
                final next = !(prefs.get<bool>(optionPluginStoreShowPrivate) == true);
                await prefs.set(optionPluginStoreShowPrivate, next);
                if (mounted) setState(() {});
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'private',
                checked: prefs.get<bool>(optionPluginStoreShowPrivate) == true,
                child: Text(l10n.plugin_store_show_private),
              ),
            ],
          ),
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
                subtitle: _catalogue.hasCache ? Text(l10n.plugin_catalogue_cached) : null,
              ),
            for (final group in groups) ...[
              _header(context, group.category.label(context)),
              for (final plugin in _orderedInCategory(group.plugins, prefs))
                if (plugin.isEnabled(prefs))
                  InstalledPluginRow(
                    plugin: plugin,
                    onUninstall: () => _uninstall(plugin),
                    onChanged: () => setState(() {}),
                  )
                else
                  AvailablePluginRow(plugin: plugin, onInstall: () => _install(plugin)),
            ],
          ],
        ),
      ),
    );
  }

  /// Installed first within a category, so what the reader already uses sits
  /// above the install buttons.
  List<XtaPlugin> _orderedInCategory(List<XtaPlugin> plugins, BasePrefService prefs) {
    final installed = plugins.where((p) => p.isEnabled(prefs)).toList();
    final available = plugins.where((p) => !p.isEnabled(prefs)).toList();
    return [...installed, ...available];
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall!
              .copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
        ),
      );
}
