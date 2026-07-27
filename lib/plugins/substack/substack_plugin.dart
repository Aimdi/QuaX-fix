import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/plugins/plugin.dart';
import 'package:quax/plugins/substack/substack_screen.dart';
import 'package:quax/plugins/substack/substack_store.dart';

class SubstackPlugin extends QuaxPlugin {
  SubstackPlugin();

  @override
  String get id => pluginIdSubstack;

  @override
  String get enabledPrefKey => optionPluginSubstackEnabled;

  @override
  String? get homeTabPrefKey => optionPluginSubstackShowTab;

  @override
  IconData get icon => Icons.newspaper_outlined;

  @override
  String title(BuildContext context) => L10n.of(context).plugin_substack_title;

  @override
  String description(BuildContext context) => L10n.of(context).plugin_substack_description;

  @override
  NavigationPage homePage(BuildContext context) {
    return NavigationPage(
      pluginIdSubstack,
      (c) => L10n.of(c).plugin_substack_title,
      const Icon(Icons.newspaper_outlined),
      const Icon(Icons.newspaper),
    );
  }

  @override
  Widget homeScreen({required ScrollController scrollController}) {
    return SubstackScreen(scrollController: scrollController);
  }

  @override
  List<String> get tables => const [tableSubstackSubscription];

  @override
  Future<void> resetPreferences(BasePrefService prefs) async {
    await prefs.set(optionPluginSubstackPublications, '[]');
    await prefs.set(optionPluginSubstackReadIds, '[]');
  }

  @override
  Future<void> forgetLoadedData(BuildContext context) async {
    await context.read<SubstackPublicationsStore>().load();
    if (context.mounted) {
      await context.read<SubstackReadStore>().load();
    }
  }
}
