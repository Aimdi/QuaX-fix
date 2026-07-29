import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_sort_sheet.dart';

/// What Reddit does outside its own tab.
class RedditSettingsScreen extends StatefulWidget {
  const RedditSettingsScreen({super.key});

  @override
  State<RedditSettingsScreen> createState() => _RedditSettingsScreenState();
}

class _RedditSettingsScreenState extends State<RedditSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final prefs = PrefService.of(context);
    final sort = storedRedditSort(prefs);
    final entry = redditSortLabel(context, sort);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plugin_reddit_title)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.plugin_reddit_in_home_feed),
            subtitle: Text(l10n.plugin_reddit_in_home_feed_description),
            value: prefs.get<bool>(optionPluginRedditInHomeFeed) == true,
            onChanged: (value) async {
              await prefs.set(optionPluginRedditInHomeFeed, value);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: Icon(entry.icon),
            title: Text(l10n.plugin_reddit_sort),
            subtitle: Text(entry.label),
            onTap: () async {
              await openRedditSortSheet(context);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
