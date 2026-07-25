import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/deepmarks/deepmarks_settings_screen.dart';
import 'package:quax/plugins/plugin.dart';

/// Saves links to Deepmarks, the Nostr-backed bookmarking service. Like the
/// Karakeep plugin this adds an action rather than a feed, plus a settings
/// screen for the API key and the signing key.
class DeepmarksPlugin extends QuaxPlugin {
  DeepmarksPlugin();

  @override
  String get id => pluginIdDeepmarks;

  @override
  String get enabledPrefKey => optionPluginDeepmarksEnabled;

  @override
  IconData get icon => Icons.bookmarks_outlined;

  @override
  String title(BuildContext context) => L10n.of(context).plugin_deepmarks_title;

  @override
  String description(BuildContext context) => L10n.of(context).plugin_deepmarks_description;

  @override
  Widget? settingsScreen(BuildContext context) => const DeepmarksSettingsScreen();
}
