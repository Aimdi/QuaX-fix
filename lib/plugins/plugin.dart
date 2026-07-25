import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quax/home/home_screen.dart';

/// Built-in QuaX plugin descriptor. Plugins are read-oriented feature packs;
/// they must not add X posting / compose capabilities.
abstract class QuaxPlugin {
  String get id;
  String get enabledPrefKey;
  IconData get icon;

  String title(BuildContext context);
  String description(BuildContext context);

  bool isEnabled(BasePrefService prefs) => prefs.get(enabledPrefKey) == true;

  Future<void> setEnabled(BasePrefService prefs, bool enabled) async {
    await prefs.set(enabledPrefKey, enabled);
  }

  /// Preference controlling whether this plugin occupies a home tab, for
  /// plugins whose feature is reachable elsewhere too. Null means the tab is
  /// not optional.
  String? get homeTabPrefKey => null;

  /// Whether the plugin should currently take up a home tab.
  bool showsHomeTab(BasePrefService prefs) {
    final key = homeTabPrefKey;
    return key == null || prefs.get(key) != false;
  }

  /// Optional home tab when the plugin is enabled.
  NavigationPage? homePage(BuildContext context) => null;

  /// Root screen for the home tab (used by [HomeScreen]).
  Widget? homeScreen({required ScrollController scrollController}) => null;

  /// Optional configuration screen, reached from the plugin store row.
  Widget? settingsScreen(BuildContext context) => null;
}
