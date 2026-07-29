import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/home/home_screen.dart';
import 'package:xta/plugins/plugin.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_screen.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';
import 'package:xta/plugins/reddit/reddit_settings_screen.dart';

/// Account-free Reddit reading, in the spirit of Stealth: no login, no posting.
///
/// A reimplementation against Reddit's documented API rather than a port of
/// Stealth itself, which is GPLv3 Kotlin — see docs/specs/reddit-plugin.md.
class RedditPlugin extends XtaPlugin {
  RedditPlugin();

  @override
  String get id => pluginIdReddit;

  @override
  String get enabledPrefKey => optionPluginRedditEnabled;

  @override
  IconData get icon => Icons.forum_outlined;

  @override
  String? get homeTabPrefKey => optionPluginRedditShowTab;

  @override
  String title(BuildContext context) => L10n.of(context).plugin_reddit_title;

  @override
  String description(BuildContext context) => L10n.of(context).plugin_reddit_description;

  @override
  NavigationPage homePage(BuildContext context) {
    return NavigationPage(
      pluginIdReddit,
      (c) => L10n.of(c).plugin_reddit_title,
      const Icon(Icons.forum_outlined),
      const Icon(Icons.forum),
    );
  }

  @override
  Widget homeScreen({required ScrollController scrollController}) {
    return RedditScreen(scrollController: scrollController);
  }

  @override
  Widget? settingsScreen(BuildContext context) => const RedditSettingsScreen();

  @override
  List<String> get tables => const [tableRedditSubscription];

  @override
  List<String> get caches => const [redditIconsCacheName];

  @override
  Future<void> resetPreferences(BasePrefService prefs) async {
    // The sign-in and the client id go with everything else: leaving
    // credentials behind is the part of "uninstall" that would matter most.
    await prefs.set(optionPluginRedditSubreddits, '[]');
    await prefs.set(optionPluginRedditClientId, '');
    await prefs.set(optionPluginRedditRefreshToken, '');
    await prefs.set(optionPluginRedditSource, redditSourceAuto);
    await prefs.set(optionPluginRedditSort, redditSortHot);
    await prefs.set(optionPluginRedditInHomeFeed, false);
  }

  @override
  Future<void> forgetLoadedData(BuildContext context) async {
    await context.read<RedditSubredditsStore>().load();
    if (context.mounted) {
      context.read<RedditClient>().forgetToken();
    }
  }
}
