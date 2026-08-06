import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_account.dart';
import 'package:xta/plugins/reddit/reddit_auth.dart';
import 'package:xta/plugins/reddit/reddit_sort_sheet.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';

/// Everything Reddit is currently doing, and every switch that changes it.
///
/// This used to be two rows — the home-feed toggle and the sort — while the
/// sign-in, the client id and the route Reddit is read through lived only in
/// the feed's overflow menu, where a reader looking for settings would not
/// think to look. The state a plugin keeps and the place its settings are is
/// not somewhere to be economical.
class RedditSettingsScreen extends StatefulWidget {
  const RedditSettingsScreen({super.key});

  @override
  State<RedditSettingsScreen> createState() => _RedditSettingsScreenState();
}

class _RedditSettingsScreenState extends State<RedditSettingsScreen> {
  late final RedditIdentityStore _identity = RedditIdentityStore(context.read<RedditAuth>());

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  @override
  void dispose() {
    _identity.destroy();
    super.dispose();
  }

  void _loadIdentity() => _identity.load(PrefService.of(context, listen: false));

  /// Anything that changes the credentials changes who Reddit says we are.
  Future<void> _afterAccountChange() async {
    if (!mounted) return;
    setState(() {});
    _loadIdentity();
  }

  Future<void> _setSource(String source) async {
    await PrefService.of(context, listen: false).set(optionPluginRedditSource, source);
    if (!mounted) return;

    setState(() {});
    _loadIdentity();
    await context.read<RedditFeedStore>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final prefs = PrefService.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plugin_reddit_title)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.account),
          _accountTile(l10n, prefs),
          _clientIdTile(l10n, prefs),
          _SectionHeader(title: l10n.plugin_reddit_source),
          _sourceTile(
            title: l10n.plugin_reddit_source_auto,
            subtitle: l10n.plugin_reddit_source_auto_description,
            icon: Icons.auto_mode,
            source: redditSourceAuto,
            selected: !redditPrefersPublic(prefs),
          ),
          _sourceTile(
            title: l10n.plugin_reddit_source_public,
            subtitle: l10n.plugin_reddit_source_public_description,
            icon: Icons.visibility_off_outlined,
            source: redditSourcePublic,
            selected: redditPrefersPublic(prefs),
          ),
          _SectionHeader(title: l10n.feed),
          _sortTile(l10n, prefs),
          SwitchListTile(
            secondary: const Icon(Icons.dynamic_feed_outlined),
            title: Text(l10n.plugin_reddit_in_home_feed),
            subtitle: Text(l10n.plugin_reddit_in_home_feed_description),
            value: prefs.get<bool>(optionPluginRedditInHomeFeed) == true,
            onChanged: (value) async {
              await prefs.set(optionPluginRedditInHomeFeed, value);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  /// Signed in or not, and — because the login asks Reddit for `identity` — as
  /// whom. A device that has been signed in to two accounts cannot answer that
  /// from "signed in" alone.
  Widget _accountTile(L10n l10n, BasePrefService prefs) {
    final signedIn = redditSignedIn(prefs);

    return ScopedBuilder<RedditIdentityStore, String?>(
      store: _identity,
      onState: (context, name) => ListTile(
        leading: Icon(signedIn ? Icons.account_circle_outlined : Icons.login),
        title: Text(signedIn ? l10n.plugin_reddit_signed_in : l10n.plugin_reddit_sign_in),
        subtitle: name == null ? null : Text('u/$name'),
        trailing: signedIn
            ? TextButton(
                onPressed: () async {
                  await signOutOfReddit(context);
                  await _afterAccountChange();
                },
                child: Text(l10n.plugin_reddit_sign_out),
              )
            : null,
        onTap: signedIn
            ? null
            : () async {
                await signInToReddit(context);
                await _afterAccountChange();
              },
      ),
    );
  }

  /// The client id is what the sign-in authorises and what the app-only route
  /// runs on, so it belongs beside the account rather than three taps away.
  Widget _clientIdTile(L10n l10n, BasePrefService prefs) {
    final clientId = redditClientId(prefs);

    return ListTile(
      leading: const Icon(Icons.key_outlined),
      title: Text(l10n.plugin_reddit_client_id),
      subtitle: Text(clientId.isEmpty ? l10n.plugin_reddit_client_id_help : clientId),
      onTap: () async {
        await editRedditClientId(context);
        await _afterAccountChange();
      },
    );
  }

  Widget _sortTile(L10n l10n, BasePrefService prefs) {
    final entry = redditSortLabel(context, storedRedditSort(prefs));

    return ListTile(
      leading: Icon(entry.icon),
      title: Text(l10n.plugin_reddit_sort),
      subtitle: Text(entry.label),
      onTap: () async {
        final chosen = await openRedditSortSheet(context);
        if (!mounted) return;

        setState(() {});
        if (chosen != null) {
          await context.read<RedditFeedStore>().refresh();
        }
      },
    );
  }

  /// One of the two routes, with what it costs stated where the choice is made
  /// rather than left for the reader to infer.
  Widget _sourceTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String source,
    required bool selected,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected ? const Icon(Icons.check) : null,
      selected: selected,
      onTap: selected ? null : () => _setSource(source),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
