import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/threads/threads_client.dart';
import 'package:xta/plugins/threads/threads_models.dart';
import 'package:xta/plugins/threads/threads_store.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';

/// Where the reader points the plugin, and who they follow with it.
class ThreadsSettingsScreen extends StatefulWidget {
  const ThreadsSettingsScreen({super.key});

  @override
  State<ThreadsSettingsScreen> createState() => _ThreadsSettingsScreenState();
}

class _ThreadsSettingsScreenState extends State<ThreadsSettingsScreen> {
  late final TextEditingController _instance;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _instance = TextEditingController(
        text: PrefService.of(context, listen: false).get<String>(optionPluginThreadsInstance) ?? '');
  }

  @override
  void dispose() {
    _instance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await PrefService.of(context, listen: false).set(optionPluginThreadsInstance, _instance.text.trim());
  }

  Future<void> _test() async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final client = context.read<ThreadsClient>();

    await _save();
    setState(() => _testing = true);
    String message;
    try {
      await client.verify(_instance.text.trim());
      message = l10n.plugin_threads_test_ok;
    } catch (e) {
      message = threadsSettingsError(l10n, e);
    }

    if (mounted) {
      setState(() => _testing = false);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _remove(String handle) async {
    await context.read<ThreadsAccountsStore>().remove(handle);
    if (mounted) {
      await context.read<ThreadsFeedStore>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plugin_threads_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.plugin_threads_settings_intro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _instance,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.plugin_threads_instance,
              hintText: l10n.plugin_threads_instance_hint,
            ),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: _testing ? null : _test,
              child: Text(l10n.plugin_threads_test),
            ),
          ),
          const Divider(height: 32),
          Text(l10n.plugin_threads_accounts, style: theme.textTheme.titleSmall),
          ScopedBuilder<ThreadsAccountsStore, List<ThreadsAccount>>(
            store: context.read<ThreadsAccountsStore>(),
            onState: (context, accounts) {
              if (accounts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(l10n.plugin_threads_no_accounts, style: theme.textTheme.bodySmall),
                );
              }
              return Column(
                children: [
                  for (final account in accounts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: FallbackAvatar(
                        seed: account.handle,
                        displayName: account.name,
                        size: 36,
                        accent: theme.colorScheme.primary,
                      ),
                      title: Text('@${account.handle}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l10n.delete,
                        onPressed: () => _remove(account.handle),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The settings screen says the same things the feed does, plus the one only a
/// test can produce: an address that is not an RSSHub at all.
String threadsSettingsError(L10n l10n, Object error) {
  if (error is! ThreadsException) {
    return l10n.plugin_threads_error_unreachable;
  }
  return switch (error.kind) {
    ThreadsErrorKind.notConfigured => l10n.plugin_threads_not_configured,
    ThreadsErrorKind.noSuchFeed => l10n.plugin_threads_error_no_route,
    ThreadsErrorKind.throttled => l10n.plugin_threads_error_throttled,
    ThreadsErrorKind.unreachable => l10n.plugin_threads_error_unreachable,
  };
}
