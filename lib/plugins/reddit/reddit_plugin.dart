import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/plugins/plugin.dart';
import 'package:quax/plugins/reddit/reddit_screen.dart';

/// Account-free Reddit reading, in the spirit of Stealth: no login, no posting.
///
/// A reimplementation against Reddit's documented API rather than a port of
/// Stealth itself, which is GPLv3 Kotlin — see docs/specs/reddit-plugin.md.
class RedditPlugin extends QuaxPlugin {
  RedditPlugin();

  @override
  String get id => pluginIdReddit;

  @override
  String get enabledPrefKey => optionPluginRedditEnabled;

  @override
  IconData get icon => Icons.forum_outlined;

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
}
