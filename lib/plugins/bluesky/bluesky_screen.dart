import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/bluesky/bluesky_client.dart';
import 'package:xta/plugins/bluesky/bluesky_models.dart';
import 'package:xta/plugins/bluesky/bluesky_post_card.dart';
import 'package:xta/plugins/bluesky/bluesky_profile_screen.dart';
import 'package:xta/plugins/bluesky/bluesky_search_sheet.dart';
import 'package:xta/plugins/bluesky/bluesky_store.dart';
import 'package:xta/ui/errors.dart';

/// The Bluesky tab: every locally followed account, merged newest first.
class BlueskyScreen extends StatefulWidget {
  final ScrollController scrollController;

  const BlueskyScreen({super.key, required this.scrollController});

  @override
  State<BlueskyScreen> createState() => _BlueskyScreenState();
}

class _BlueskyScreenState extends State<BlueskyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BlueskyFeedStore>().refresh();
      }
    });
  }

  Future<void> _searchPeople() async {
    await showBlueskySearchSheet(context);
    if (mounted) {
      await context.read<BlueskyFeedStore>().refresh();
    }
  }

  Future<void> _addAccount() async {
    final actor = await showBlueskyAddAccountDialog(context);
    if (actor == null || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final client = context.read<BlueskyClient>();
    final accounts = context.read<BlueskyAccountsStore>();
    final l10n = L10n.of(context);

    try {
      final profile = await client.getProfile(actor);
      await accounts.add(profile.toAccount());
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(blueskyErrorMessage(l10n, e))));
      }
      return;
    }

    if (mounted) {
      await context.read<BlueskyFeedStore>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_bluesky_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.plugin_bluesky_search,
            onPressed: _searchPeople,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: l10n.plugin_bluesky_add,
            onPressed: _addAccount,
          ),
        ],
      ),
      body: ScopedBuilder<BlueskyFeedStore, List<BlueskyPost>>.transition(
        store: context.read<BlueskyFeedStore>(),
        onLoading: (_) => const Center(child: CircularProgressIndicator()),
        onError: (context, error) => Padding(
          padding: const EdgeInsets.all(24),
          child: FullPageErrorWidget(
            error: error,
            stackTrace: null,
            prefix: blueskyErrorMessage(l10n, error ?? Exception()),
            onRetry: () => context.read<BlueskyFeedStore>().refresh(),
          ),
        ),
        onState: (context, posts) => _feed(context, l10n, posts),
      ),
    );
  }

  Widget _feed(BuildContext context, L10n l10n, List<BlueskyPost> posts) {
    if (posts.isEmpty) {
      return ScopedBuilder<BlueskyAccountsStore, List<BlueskyAccount>>(
        store: context.read<BlueskyAccountsStore>(),
        onState: (context, accounts) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              accounts.isEmpty ? l10n.plugin_bluesky_empty : l10n.plugin_bluesky_no_posts,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<BlueskyFeedStore>().refresh(),
      child: ListView.builder(
        controller: widget.scrollController,
        itemCount: posts.length,
        itemBuilder: (context, index) =>
            BlueskyPostCard(key: ValueKey(posts[index].uri), post: posts[index], showSourceBadge: false),
      ),
    );
  }
}

/// Asks for a handle or DID, and hands back the normalised one.
Future<String?> showBlueskyAddAccountDialog(BuildContext context, {bool lookup = false}) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final l10n = L10n.of(dialogContext);
      String? error;

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(lookup ? l10n.plugin_bluesky_lookup : l10n.plugin_bluesky_add),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.plugin_bluesky_handle_hint,
              errorText: error,
            ),
            onSubmitted: (_) {
              final handle = normaliseBlueskyHandle(controller.text);
              if (handle == null) {
                setState(() => error = l10n.plugin_bluesky_invalid_handle);
              } else {
                Navigator.pop(context, handle);
              }
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () {
                final handle = normaliseBlueskyHandle(controller.text);
                if (handle == null) {
                  setState(() => error = l10n.plugin_bluesky_invalid_handle);
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
