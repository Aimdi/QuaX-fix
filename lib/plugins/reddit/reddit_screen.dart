import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/reddit/reddit_auth.dart';
import 'package:quax/plugins/reddit/reddit_login_webview.dart';
import 'package:quax/plugins/reddit/reddit_client.dart';
import 'package:quax/plugins/reddit/reddit_post_card.dart';
import 'package:quax/plugins/reddit/reddit_store.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/errors.dart';

String redditErrorMessage(L10n l10n, Object error) {
  if (error is RedditException) {
    final explanation = switch (error.kind) {
      RedditErrorKind.notConfigured => l10n.plugin_reddit_not_configured,
      RedditErrorKind.unauthorized => l10n.plugin_reddit_error_client_id,
      RedditErrorKind.blocked => l10n.plugin_reddit_error_blocked,
      RedditErrorKind.notFound => l10n.plugin_reddit_error_not_found,
      RedditErrorKind.rateLimited => l10n.plugin_reddit_error_rate_limited,
      RedditErrorKind.badResponse => l10n.plugin_reddit_error_response,
      RedditErrorKind.network => l10n.plugin_reddit_error_network,
    };

    // The translated sentence says what to do; the detail says what actually
    // happened. Without it a refusal, a timeout and a reshaped response all
    // read the same, and "it doesn't work" is all anyone can report back.
    return error.detail.isEmpty ? explanation : '$explanation\n\n${error.detail}';
  }
  return '$error';
}

/// Account-free Reddit reading: the subreddits you follow, newest first.
class RedditScreen extends StatefulWidget {
  final ScrollController scrollController;

  const RedditScreen({super.key, required this.scrollController});

  @override
  State<RedditScreen> createState() => _RedditScreenState();
}

class _RedditScreenState extends State<RedditScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final subs = context.read<RedditSubredditsStore>();
      await subs.load();
      if (mounted) {
        await context.read<RedditFeedStore>().refresh();
      }
    });
  }

  /// Which route Reddit is read through.
  ///
  /// The client would otherwise decide silently from whatever credentials
  /// happen to be stored, so a reader who would rather not be identified had no
  /// way to say so while a sign-in existed.
  Widget _sourceMenu(BuildContext context) {
    final prefs = PrefService.of(context);
    final current = prefs.get<String>(optionPluginRedditSource) ?? redditSourceAuto;
    final l10n = L10n.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.alt_route),
      tooltip: l10n.plugin_reddit_source,
      initialValue: current,
      onSelected: (value) async {
        await prefs.set(optionPluginRedditSource, value);
        if (mounted) {
          await context.read<RedditFeedStore>().refresh();
        }
      },
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
      ],
    );
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

  Future<void> _addSubreddit() async {
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

    if (entered == null || entered.isEmpty || !mounted) return;

    if (normaliseSubreddit(entered) == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L10n.of(context).plugin_reddit_error_not_found)));
      return;
    }

    await context.read<RedditSubredditsStore>().add(entered);
    if (mounted) {
      await _refreshAfterChange(context);
    }
  }

  /// The feed and the subscription list both have to hear about it: a subreddit
  /// is a group member now, and the group editor reads that list rather than
  /// the store this screen keeps.
  static Future<void> _refreshAfterChange(BuildContext context) async {
    final subscriptions = context.read<SubscriptionsModel>();
    await context.read<RedditFeedStore>().refresh();
    await subscriptions.reloadSubscriptions();
  }

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
                          await _refreshAfterChange(sheetContext);
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
    final feed = context.read<RedditFeedStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_reddit_title),
        actions: [
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
          IconButton(
            tooltip: _signedIn ? l10n.plugin_reddit_sign_out : l10n.plugin_reddit_sign_in,
            icon: Icon(_signedIn ? Icons.logout : Icons.login),
            onPressed: _signedIn ? _signOut : _signIn,
          ),
          IconButton(
            tooltip: l10n.plugin_reddit_client_id,
            icon: const Icon(Icons.key),
            onPressed: _editClientId,
          ),
          _sourceMenu(context),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: feed.refresh,
        child: ScopedBuilder<RedditFeedStore, List<RedditPost>>.transition(
          store: feed,
          onError: (_, error) => FullPageErrorWidget(
            error: error,
            stackTrace: null,
            prefix: redditErrorMessage(l10n, error!),
            onRetry: feed.refresh,
          ),
          onLoading: (_) => const Center(child: CircularProgressIndicator()),
          onState: (_, posts) {
            if (posts.isEmpty) {
              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                children: [
                  Icon(Icons.forum_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(l10n.plugin_reddit_empty, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  // Telling the reader to add a subreddit and then leaving the
                  // only control in the app bar is how this screen managed to
                  // look broken when it was merely empty.
                  Center(
                    child: FilledButton.icon(
                      onPressed: _addSubreddit,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.plugin_reddit_add),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              controller: widget.scrollController,
              itemCount: posts.length,
              // The cards carry their own hairline.
              separatorBuilder: (_, _) => const SizedBox.shrink(),
              itemBuilder: (context, index) => RedditPostCard(post: posts[index], showSourceBadge: false),
            );
          },
        ),
      ),
    );
  }
}
