import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/bluesky/bluesky_client.dart';
import 'package:xta/plugins/bluesky/bluesky_models.dart';
import 'package:xta/plugins/bluesky/bluesky_profile_screen.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';

/// Search people on the public AppView and open a profile from the results.
Future<void> showBlueskySearchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const _BlueskySearchSheet(),
  );
}

class _BlueskySearchSheet extends StatefulWidget {
  const _BlueskySearchSheet();

  @override
  State<_BlueskySearchSheet> createState() => _BlueskySearchSheetState();
}

class _BlueskySearchSheetState extends State<_BlueskySearchSheet> {
  final _controller = TextEditingController();
  List<BlueskyProfile> _results = const [];
  Object? _error;
  var _loading = false;
  var _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openActor(String actor) async {
    if (!mounted) return;
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BlueskyProfileScreen(actor: actor)),
    );
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }

    // Exact handle, DID, or profile URL — open that profile without searching.
    final direct = normaliseBlueskyHandle(query);
    if (direct != null) {
      await _openActor(direct);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });

    try {
      final results = await context.read<BlueskyClient>().searchActors(query, limit: 20);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _results = const [];
      });
    }
  }

  Future<void> _open(BlueskyProfile profile) async {
    final actor = profile.did.isNotEmpty ? profile.did : profile.handle;
    await _openActor(actor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.plugin_bluesky_search_hint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: l10n.plugin_bluesky_search,
                    onPressed: _search,
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            Expanded(child: _body(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _body(L10n l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(blueskyErrorMessage(l10n, _error!), textAlign: TextAlign.center),
        ),
      );
    }
    if (_searched && _results.isEmpty) {
      return Center(child: Text(l10n.plugin_bluesky_no_results));
    }
    if (!_searched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.plugin_bluesky_search_hint, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final profile = _results[index];
        return ListTile(
          leading: _avatar(context, profile),
          title: Text(profile.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('@${profile.handle}', maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _open(profile),
        );
      },
    );
  }

  Widget _avatar(BuildContext context, BlueskyProfile profile) {
    final theme = Theme.of(context);
    final avatar = profile.avatarUrl;
    return ClipOval(
      child: avatar == null
          ? FallbackAvatar(
              seed: profile.handle,
              displayName: profile.displayName,
              size: 40,
              accent: theme.colorScheme.primary,
            )
          : ExtendedImage.network(
              avatar,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              cacheWidth: (40 * MediaQuery.devicePixelRatioOf(context)).ceil(),
            ),
    );
  }
}
