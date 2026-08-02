import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/settings/_about.dart';
import 'package:xta/settings/_ai.dart';
import 'package:xta/settings/_accessibility.dart';
import 'package:xta/settings/_account.dart';
import 'package:xta/settings/_data.dart';
import 'package:xta/settings/_general.dart';
import 'package:xta/settings/_home.dart';
import 'package:xta/settings/_media.dart';
import 'package:xta/settings/_plugin_store.dart';
import 'package:xta/settings/_posts.dart';
import 'package:xta/settings/_theme.dart';
import 'package:xta/settings/diagnostics_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  final String? initialPage;

  const SettingsScreen({super.key, this.initialPage});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// One navigable settings section: its icon, its title, a plain description of
/// what it holds, and where it goes.
class _SettingsEntry {
  final IconData icon;
  final String title;
  final String description;
  final WidgetBuilder builder;

  const _SettingsEntry(
      {required this.icon, required this.title, required this.description, required this.builder});

  bool matches(String query) =>
      title.toLowerCase().contains(query) || description.toLowerCase().contains(query);
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo _packageInfo = PackageInfo(appName: '', packageName: '', version: '', buildNumber: '');
  String _query = '';

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      var packageInfo = await PackageInfo.fromPlatform();

      setState(() {
        _packageInfo = packageInfo;
      });
    });
  }

  List<_SettingsEntry> _entries(BuildContext context, Key key) {
    final l10n = L10n.of(context);
    return [
      _SettingsEntry(
        icon: Icons.miscellaneous_services,
        title: l10n.general,
        description:
            "${l10n.language}, ${l10n.should_check_for_updates_label}, ${l10n.disable_screenshots}, ${l10n.default_tab}, ${l10n.share_base_url}, ${l10n.crash_reports_enabled}",
        builder: (context) => const SettingsGeneralFragment(),
      ),
      _SettingsEntry(
        icon: Icons.article,
        title: l10n.tweets,
        description:
            "${l10n.use_absolute_timestamp}, ${l10n.hide_sensitive_tweets}, ${l10n.always_show_full_tweet_contents}, ${l10n.activate_non_confirmation_bias_mode_label}",
        builder: (context) => const SettingsPostsFragment(),
      ),
      _SettingsEntry(
        icon: Icons.perm_media,
        title: l10n.media,
        description: "${l10n.image_quality}, ${l10n.video_quality}, ${l10n.mute_videos}, ${l10n.download_handling}",
        builder: (context) => const SettingsMediaFragment(),
      ),
      _SettingsEntry(
        icon: Icons.account_circle,
        title: l10n.account,
        description: l10n.account,
        builder: (context) => SettingsAccountFragment(key: key),
      ),
      _SettingsEntry(
        icon: Icons.home,
        title: l10n.home,
        description: "${l10n.reset_home_pages}, ${l10n.home}",
        builder: (context) => const SettingsHomeFragment(),
      ),
      _SettingsEntry(
        icon: Icons.palette,
        title: l10n.theme,
        description:
            "${l10n.theme_mode}, ${l10n.theme}, ${l10n.true_black}, ${l10n.true_black_tweet_cards} ${l10n.show_navigation_labels}",
        builder: (context) => const SettingsThemeFragment(),
      ),
      _SettingsEntry(
        icon: Icons.settings_accessibility,
        title: l10n.accessibility,
        description: "${l10n.text_scale_factor}, ${l10n.disable_animations}",
        builder: (context) => const SettingsAccessibilityFragment(),
      ),
      _SettingsEntry(
        icon: Icons.extension_outlined,
        title: l10n.plugin_store,
        description: l10n.plugin_store_description,
        builder: (context) => const SettingsPluginStoreFragment(),
      ),
      _SettingsEntry(
        icon: Icons.auto_awesome_outlined,
        title: l10n.ai_provider,
        description: l10n.ai_provider_description,
        builder: (context) => const SettingsAiFragment(),
      ),
      _SettingsEntry(
        icon: Icons.monitor_heart_outlined,
        title: l10n.diagnostics,
        description: l10n.diagnostics_description,
        builder: (context) => const DiagnosticsScreen(),
      ),
    ];
  }

  Widget _entryTile(BuildContext context, _SettingsEntry entry) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(entry.icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(entry.title, style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(entry.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: entry.builder)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    var key = widget.key ?? const Key("Settings");
    var appVersion = 'v${_packageInfo.version}+${_packageInfo.buildNumber}';
    final query = _query.trim().toLowerCase();
    final entries = _entries(context, key).where((e) => query.isEmpty || e.matches(query)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.only(bottom: 16.0 + MediaQuery.of(context).padding.bottom),
        children: [
          // X puts a search field at the top of Settings; here it filters the
          // sections by title or by what each one contains.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.search_settings,
                isDense: true,
              ),
            ),
          ),
          for (final entry in entries) _entryTile(context, entry),
          if (query.isEmpty) ...[
            const Divider(),
            _SectionLabel(l10n.data),
            SettingsDataFragment(),
            const Divider(),
            _SectionLabel(l10n.app_info),
            SettingsAboutFragment(appVersion: appVersion),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(label,
          style: theme.textTheme.titleSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}
