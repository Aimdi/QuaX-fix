import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_auth.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_login_webview.dart';
import 'package:xta/plugins/reddit/reddit_search_screen.dart';
import 'package:xta/plugins/reddit/reddit_sort_sheet.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';
import 'package:xta/subscriptions/users_model.dart';
import 'package:xta/ui/errors.dart';

/// The controls a Reddit feed needs, wherever it is being shown.
///
/// Reddit is two screens now — its own tab and an entry in the home switcher —
/// and the second one arrived with only the generic feed actions, so sorting,
/// searching and adding a subreddit were all missing from it. They live here so
/// there is one set rather than two that drift.
///
/// Returns a Row so it can sit as a single entry in an `AppBar.actions` list.
class RedditFeedActions extends StatefulWidget {
  /// Adds the app's own settings to the overflow menu, for a bar that has no
  /// other route to them.
  final bool showAppSettings;

  const RedditFeedActions({super.key, this.showAppSettings = false});

  @override
  State<RedditFeedActions> createState() => _RedditFeedActionsState();
}

class _RedditFeedActionsState extends State<RedditFeedActions> {

  /// Which route Reddit is read through.
  ///
  /// The client would otherwise decide silently from whatever credentials
  /// happen to be stored, so a reader who would rather not be identified had no
  /// way to say so while a sign-in existed.
  Widget _sourceMenu(BuildContext context) {
    final prefs = PrefService.of(context);
    final l10n = L10n.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.plugin_reddit_source,
      onSelected: (value) => _onMenuSelected(value, prefs),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: redditSourceAuto,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.plugin_reddit_source_auto),
            subtitle: Text(l10n.plugin_reddit_source_auto_description),
          ),
        ),
        PopupMenuItem(
          value: redditSourcePublic,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.plugin_reddit_source_public),
            subtitle: Text(l10n.plugin_reddit_source_public_description),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _menuSignIn,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_signedIn ? Icons.logout : Icons.login),
            title: Text(_signedIn ? l10n.plugin_reddit_sign_out : l10n.plugin_reddit_sign_in),
          ),
        ),
        PopupMenuItem(
          value: _menuClientId,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key),
            title: Text(l10n.plugin_reddit_client_id),
          ),
        ),
        if (widget.showAppSettings)
          PopupMenuItem(
            value: _menuAppSettings,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings),
              title: Text(l10n.settings),
            ),
          ),
      ],
    );
  }

  /// Values the menu uses for the actions that are not a source choice.
  static const _menuSignIn = '_signIn';
  static const _menuClientId = '_clientId';
  static const _menuAppSettings = '_appSettings';

  Future<void> _onMenuSelected(String value, BasePrefService prefs) async {
    if (value == _menuSignIn) {
      return _signedIn ? _signOut() : _signIn();
    }
    if (value == _menuClientId) {
      return _editClientId();
    }
    if (value == _menuAppSettings) {
      Navigator.pushNamed(context, routeSettings);
      return;
    }

    await prefs.set(optionPluginRedditSource, value);
    if (mounted) {
      await context.read<RedditFeedStore>().refresh();
    }
  }

  Future<void> _editClientId() async {
    final prefs = PrefService.of(context, listen: false);
    final controller = TextEditingController(text: prefs.get<String>(optionPluginRedditClientId) ?? '');

    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = L10n.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.plugin_reddit_client_id),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.plugin_reddit_client_id_help, style: Theme.of(dialogContext).textTheme.bodySmall),
              const SizedBox(height: 8),
              // Reddit rejects the login unless the registered app carries this
              // exact redirect, and it is not guessable — so it is stated here
              // rather than left to be discovered.
              Text(
                l10n.plugin_reddit_redirect_uri_help(RedditAuth.redirectUri),
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                decoration: InputDecoration(hintText: l10n.plugin_reddit_client_id),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    if (saved == null || !mounted) return;
    await prefs.set(optionPluginRedditClientId, saved);
    context.read<RedditClient>().forgetToken();
    if (mounted) {
      await context.read<RedditFeedStore>().refresh();
    }
  }

  bool get _signedIn => (PrefService.of(context, listen: false).get<String>(optionPluginRedditRefreshToken) ?? '')
      .isNotEmpty;

  /// Signing in gets the reader their own account's rate limits, which is the
  /// most reliable route Reddit offers. It still needs a client id: the login
  /// authorises *this app*, and Reddit has to know which app that is.
  Future<void> _signIn() async {
    final prefs = PrefService.of(context, listen: false);
    final clientId = prefs.get<String>(optionPluginRedditClientId) ?? '';
    if (clientId.trim().isEmpty) {
      await _editClientId();
      return;
    }

    // Echoed back by Reddit and checked on return, so a code from anywhere
    // else is refused.
    final state = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => RedditLoginWebview(clientId: clientId, state: state)),
    );

    if (code == null || !mounted) return;

    try {
      final refreshToken = await context.read<RedditAuth>().exchangeCode(clientId: clientId, code: code);
      await prefs.set(optionPluginRedditRefreshToken, refreshToken);
      if (mounted) {
        setState(() {});
        // The webview closing is not by itself proof the token was accepted.
        showSnackBar(context, icon: '✅', message: L10n.of(context).plugin_reddit_signed_in);
        await context.read<RedditFeedStore>().refresh();
      }
    } on RedditException catch (e) {
      if (mounted) {
        showSnackBar(context, icon: '🔒', message: '${L10n.of(context).plugin_reddit_sign_in_failed}\n${e.detail}');
      }
    }
  }

  Future<void> _signOut() async {
    final prefs = PrefService.of(context, listen: false);
    await prefs.set(optionPluginRedditRefreshToken, '');
    if (mounted) {
      setState(() {});
      await context.read<RedditFeedStore>().refresh();
    }
  }

  Future<void> _addSubreddit() => addRedditSubreddit(context);

  Future<void> _manageSubreddits() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final store = sheetContext.read<RedditSubredditsStore>();
        return SafeArea(
          child: ScopedBuilder<RedditSubredditsStore, List<String>>(
            store: store,
            onState: (_, names) => ListView(
              shrinkWrap: true,
              children: [
                for (final name in names)
                  ListTile(
                    title: Text('r/$name'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await store.remove(name);
                        if (sheetContext.mounted) {
                          await refreshAfterRedditChange(sheetContext);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.plugin_reddit_sort,
          icon: Icon(redditSortLabel(context, storedRedditSort(PrefService.of(context))).icon),
          onPressed: () async {
            if (await openRedditSortSheet(context) != null && mounted) {
              await context.read<RedditFeedStore>().refresh();
            }
          },
        ),
        IconButton(
          tooltip: l10n.plugin_reddit_search_hint,
          icon: const Icon(Icons.search),
          onPressed: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RedditSearchScreen())),
        ),
        IconButton(
          tooltip: l10n.plugin_reddit_add,
          icon: const Icon(Icons.add),
          onPressed: _addSubreddit,
        ),
        IconButton(
          tooltip: l10n.subscriptions,
          icon: const Icon(Icons.list),
          onPressed: _manageSubreddits,
        ),
        _sourceMenu(context),
      ],
    );
  }
}

/// Asks for a subreddit and follows it.
///
/// A function rather than a method: the app bar offers it, and so does the
/// empty feed, which is the screen a reader with no subreddits actually sees.
Future<void> addRedditSubreddit(BuildContext context) async {
  final controller = TextEditingController();
  final entered = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final l10n = L10n.of(dialogContext);
      return AlertDialog(
        title: Text(l10n.plugin_reddit_add),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'r/dartlang'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.ok),
          ),
        ],
      );
    },
  );

  if (entered == null || entered.isEmpty || !context.mounted) return;

  if (normaliseSubreddit(entered) == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(L10n.of(context).plugin_reddit_error_not_found)));
    return;
  }

  await context.read<RedditSubredditsStore>().add(entered);
  if (context.mounted) {
    await refreshAfterRedditChange(context);
  }
}

/// The feed and the subscription list both have to hear about a change: a
/// subreddit is a group member too, and the group editor reads that list rather
/// than the store the Reddit screens keep.
Future<void> refreshAfterRedditChange(BuildContext context) async {
  final subscriptions = context.read<SubscriptionsModel>();
  await context.read<RedditFeedStore>().refresh();
  await subscriptions.reloadSubscriptions();
}
