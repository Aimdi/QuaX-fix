import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/threads/threads_client.dart';
import 'package:xta/plugins/threads/threads_models.dart';
import 'package:xta/plugins/threads/threads_post_card.dart';
import 'package:xta/plugins/threads/threads_profile_screen.dart';
import 'package:xta/plugins/threads/threads_settings.dart';
import 'package:xta/plugins/threads/threads_store.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';
import 'package:xta/ui/errors.dart';

/// What a failed Threads read should say, in the reader's terms.
String threadsErrorMessage(L10n l10n, Object error) {
  if (error is! ThreadsException) {
    return l10n.plugin_threads_error_unreachable;
  }
  return switch (error.kind) {
    ThreadsErrorKind.notConfigured => l10n.plugin_threads_not_configured,
    ThreadsErrorKind.noSuchFeed => l10n.plugin_threads_error_no_feed,
    ThreadsErrorKind.throttled => l10n.plugin_threads_error_throttled,
    ThreadsErrorKind.unreachable => l10n.plugin_threads_error_unreachable,
    ThreadsErrorKind.unauthorized => l10n.plugin_threads_error_unauthorized,
    ThreadsErrorKind.sessionSuspended => l10n.plugin_threads_error_session_suspended,
  };
}

/// The Threads tab: every followed account, merged newest first.
class ThreadsScreen extends StatefulWidget {
  final ScrollController scrollController;

  const ThreadsScreen({super.key, required this.scrollController});

  @override
  State<ThreadsScreen> createState() => _ThreadsScreenState();
}

class _ThreadsScreenState extends State<ThreadsScreen> {
  @override
  void initState() {
    super.initState();
    // The accounts are already loaded at startup; the feed is not, because it
    // is a request per account and nobody asked for it until this tab exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ThreadsFeedStore>().refresh();
      }
    });
  }

  /// Looks a handle up on the Xy server and shows whoever it finds, so an
  /// account can be seen before it is followed.
  Future<void> _lookUpProfile() async {
    final handle = await showThreadsAddAccountDialog(context, lookup: true);
    if (handle == null || !mounted) {
      return;
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadsProfileScreen(username: handle)));
  }

  Future<void> _addAccount() async {
    final handle = await showThreadsAddAccountDialog(context);
    if (handle == null || !mounted) {
      return;
    }

    await context.read<ThreadsAccountsStore>().add(ThreadsAccount(handle: handle, name: handle));
    if (mounted) {
      await context.read<ThreadsFeedStore>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_threads_title),
        actions: [
          IconButton(icon: const Icon(Icons.search), tooltip: l10n.plugin_threads_lookup, onPressed: _lookUpProfile),
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: l10n.plugin_threads_add_account,
            onPressed: _addAccount,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThreadsSettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          const ThreadsFollowingStrip(),
          Expanded(
            child: ScopedBuilder<ThreadsFeedStore, List<ThreadsPost>>.transition(
              store: context.read<ThreadsFeedStore>(),
              onLoading: (_) => const Center(child: CircularProgressIndicator()),
              onError: (context, error) => Padding(
                padding: const EdgeInsets.all(24),
                child: FullPageErrorWidget(
                  error: error,
                  stackTrace: null,
                  prefix: threadsErrorMessage(l10n, error ?? Exception()),
                  onRetry: () => context.read<ThreadsFeedStore>().refresh(),
                ),
              ),
              onState: (context, posts) => _feed(context, l10n, posts),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feed(BuildContext context, L10n l10n, List<ThreadsPost> posts) {
    if (posts.isEmpty) {
      return ScopedBuilder<ThreadsAccountsStore, List<ThreadsAccount>>(
        store: context.read<ThreadsAccountsStore>(),
        onState: (context, accounts) => ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Text(
              accounts.isEmpty ? l10n.plugin_threads_no_accounts : l10n.plugin_threads_no_posts,
              textAlign: TextAlign.center,
            ),
            // Naming who is followed turns "nothing here" into something the
            // reader can act on: an empty feed with three accounts in it is a
            // different problem from an empty feed with none.
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 24),
              for (final account in accounts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: FallbackAvatar(
                    seed: account.handle,
                    displayName: account.name,
                    size: 36,
                    accent: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text('@${account.handle}'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ThreadsProfileScreen(username: account.handle)),
                  ),
                ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      // The reader pulled: that is the one moment worth going past the cache.
      onRefresh: () => context.read<ThreadsFeedStore>().refresh(force: true),
      child: ListView.builder(
        controller: widget.scrollController,
        itemCount: posts.length,
        itemBuilder: (context, index) =>
            ThreadsPostCard(key: ValueKey(posts[index].id), post: posts[index], showSourceBadge: false),
      ),
    );
  }
}

/// Who the reader follows on Threads, along the top of the tab.
///
/// The list used to live only in Settings, which meant the tab could show an
/// empty feed with no way to tell whether that was because nobody was followed
/// or because the fetch came back with nothing. A row of faces answers that
/// before the feed loads, and each one opens the profile it belongs to.
class ThreadsFollowingStrip extends StatelessWidget {
  const ThreadsFollowingStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScopedBuilder<ThreadsAccountsStore, List<ThreadsAccount>>(
      store: context.read<ThreadsAccountsStore>(),
      onState: (context, accounts) {
        if (accounts.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final account = accounts[index];

              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ThreadsProfileScreen(username: account.handle)),
                ),
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FallbackAvatar(
                        seed: account.handle,
                        displayName: account.name,
                        size: 40,
                        accent: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account.handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Asks for a handle, and hands back the normalised one.
Future<String?> showThreadsAddAccountDialog(BuildContext context, {bool lookup = false}) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final l10n = L10n.of(dialogContext);
      String? error;

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(lookup ? l10n.plugin_threads_lookup : l10n.plugin_threads_add_account),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.plugin_threads_account_hint, errorText: error, prefixText: '@'),
            onSubmitted: (_) {
              final handle = normaliseThreadsHandle(controller.text);
              if (handle == null) {
                setState(() => error = l10n.plugin_threads_invalid_handle);
              } else {
                Navigator.pop(context, handle);
              }
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () {
                final handle = normaliseThreadsHandle(controller.text);
                if (handle == null) {
                  setState(() => error = l10n.plugin_threads_invalid_handle);
                } else {
                  Navigator.pop(context, handle);
                }
              },
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    },
  );
}
