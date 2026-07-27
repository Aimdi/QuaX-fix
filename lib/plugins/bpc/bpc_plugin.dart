import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/bpc/bpc_settings_screen.dart';
import 'package:quax/plugins/plugin.dart';

/// Mobile adaptation of Bypass Paywalls Clean for outbound article links.
///
/// Does not run the Chrome extension itself. When enabled, known paywalled
/// domains are opened in an in-app reader using a bypass strategy instead of
/// being handed straight to the browser.
class BpcPlugin extends QuaxPlugin {
  BpcPlugin();

  @override
  String get id => pluginIdBpc;

  @override
  String get enabledPrefKey => optionPluginBpcEnabled;

  @override
  IconData get icon => Icons.lock_open_outlined;

  @override
  String title(BuildContext context) => L10n.of(context).plugin_bpc_title;

  @override
  String description(BuildContext context) => L10n.of(context).plugin_bpc_description;

  @override
  Widget settingsScreen(BuildContext context) => const BpcSettingsScreen();
}
