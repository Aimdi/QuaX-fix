import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/threads/threads_api.dart';
import 'package:xta/plugins/threads/threads_client.dart';
import 'package:xta/plugins/threads/threads_direct_client.dart';
import 'package:xta/plugins/threads/threads_models.dart';
import 'package:xta/plugins/threads/threads_settings.dart';
import 'package:xta/plugins/threads/threads_store.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';
import 'package:xta/ui/errors.dart';
import 'package:xta/utils/urls.dart';

/// What a failed Xy lookup should say.
///
/// The server writes a sentence for a person and sends it as `message`; that is
/// preferred over anything this app could invent, and the generic lines are
/// only for when it said nothing.
String threadsApiErrorMessage(L10n l10n, Object error) {
  if (error is ThreadsException) {
    return threadsSettingsError(l10n, error);
  }
  if (error is! ThreadsApiException) {
    return l10n.plugin_threads_error_unreachable;
  }
  final said = error.message?.trim();
  if (said != null && said.isNotEmpty) {
    return said;
  }
  return switch (error.kind) {
    ThreadsApiErrorKind.notConfigured => l10n.plugin_threads_api_not_configured,
    ThreadsApiErrorKind.unauthorized => l10n.plugin_threads_api_unauthorized,
    ThreadsApiErrorKind.notFound => l10n.plugin_threads_error_no_feed,
    ThreadsApiErrorKind.unreachable => l10n.plugin_threads_error_unreachable,
    ThreadsApiErrorKind.upstream => l10n.plugin_threads_error_unreachable,
  };
}

/// One Threads profile, looked up through the reader's Xy server.
class ThreadsProfileScreen extends StatefulWidget {
  final String username;

  const ThreadsProfileScreen({super.key, required this.username});

  @override
  State<ThreadsProfileScreen> createState() => _ThreadsProfileScreenState();
}

class _ThreadsProfileScreenState extends State<ThreadsProfileScreen> {
  ThreadsProfile? _profile;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = PrefService.of(context, listen: false);
    final direct = context.read<ThreadsDirectClient>();
    final api = context.read<ThreadsApi>();
    final apiBase = prefs.get<String>(optionPluginThreadsApiBase) ?? kThreadsApiDefaultBase;
    final apiToken = prefs.get<String>(optionPluginThreadsApiToken) ?? '';
    try {
      // Public site first — the same page a browser shows without logging in.
      // Cookies / Xy only step in when that fails.
      ThreadsProfile? profile;
      Object? lastError;
      try {
        profile = await direct.fetchGuestProfile(widget.username);
      } catch (e) {
        lastError = e;
      }
      if (profile == null && direct.hasCookies) {
        try {
          profile = await direct.fetchProfile(widget.username);
        } catch (e) {
          lastError = e;
        }
      }
      if (profile == null) {
        try {
          profile = await api.profile(apiBase, apiToken, widget.username);
        } catch (e) {
          lastError = e;
        }
      }
      if (!mounted) {
        return;
      }
      if (profile == null) {
        setState(() {
          _error = lastError ?? ThreadsException(ThreadsErrorKind.noSuchFeed, 'profile missing');
          _loading = false;
        });
        return;
      }
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _follow(ThreadsProfile profile) async {
    final messenger = ScaffoldMessenger.of(context);
    final added = L10n.of(context).plugin_threads_account_added;

    await context.read<ThreadsAccountsStore>().add(profile.toAccount());
    if (mounted) {
      await context.read<ThreadsFeedStore>().refresh();
    }
    messenger.showSnackBar(SnackBar(content: Text(added)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}')),
      body: _body(context, l10n),
    );
  }

  Widget _body(BuildContext context, L10n l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: threadsApiErrorMessage(l10n, error),
          onRetry: _load,
        ),
      );
    }

    final profile = _profile!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [ThreadsProfileCard(profile: profile, onFollow: () => _follow(profile))],
    );
  }
}

/// The profile itself: face, name, what they say about themselves, and what
/// they have gathered.
class ThreadsProfileCard extends StatelessWidget {
  final ThreadsProfile profile;
  final VoidCallback? onFollow;

  const ThreadsProfileCard({super.key, required this.profile, this.onFollow});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final numbers = NumberFormat.compact();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipOval(
              child: profile.profilePicUrl.isEmpty
                  ? FallbackAvatar(
                      seed: profile.username,
                      displayName: profile.displayName,
                      size: 64,
                      accent: theme.colorScheme.primary,
                    )
                  : ExtendedImage.network(
                      profile.profilePicUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      cacheWidth: (64 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified, size: 20, color: theme.colorScheme.primary),
                      ],
                      if (profile.isPrivate) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ],
                  ),
                  Text(
                    '@${profile.username}',
                    style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (profile.biography.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(profile.biography.trim(), style: theme.textTheme.bodyMedium),
        ],
        if (profile.externalUrl != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => openUri(context, profile.externalUrl!),
            child: Row(
              children: [
                Icon(Icons.link, size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    profile.externalUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _count(context, numbers.format(profile.followerCount), l10n.followers),
            _count(context, numbers.format(profile.followingCount), l10n.following),
            _count(context, numbers.format(profile.mediaCount), l10n.tweets),
          ],
        ),
        if (onFollow != null) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onFollow,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.plugin_threads_add_account),
            ),
          ),
        ],
        if (profile.isPrivate) ...[
          const SizedBox(height: 14),
          Text(l10n.plugin_threads_profile_private, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _count(BuildContext context, String value, String label) {
    final theme = Theme.of(context);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      style: theme.textTheme.bodyMedium,
    );
  }
}
