import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/karakeep/karakeep_settings_screen.dart';
import 'package:quax/plugins/plugin.dart';

/// Sends links to a self-hosted Karakeep instance. No home tab: the plugin adds
/// a save action where links already are, plus its own settings screen.
class KarakeepPlugin extends QuaxPlugin {
  KarakeepPlugin();

  @override
  String get id => pluginIdKarakeep;

  @override
  String get enabledPrefKey => optionPluginKarakeepEnabled;

  @override
  IconData get icon => Icons.bookmark_add_outlined;

  @override
  String title(BuildContext context) => L10n.of(context).plugin_karakeep_title;

  @override
  String description(BuildContext context) => L10n.of(context).plugin_karakeep_description;

  @override
  Widget? settingsScreen(BuildContext context) => const KarakeepSettingsScreen();

  @override
  Future<void> resetPreferences(BasePrefService prefs) async {
    await prefs.set(optionPluginKarakeepServerUrl, '');
    await prefs.set(optionPluginKarakeepApiKey, '');
  }
}
