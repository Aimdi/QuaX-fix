import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/mastodon/mastodon_client.dart';
import 'package:xta/plugins/mastodon/mastodon_models.dart';
import 'package:xta/plugins/mastodon/mastodon_post_card.dart';
import 'package:xta/plugins/mastodon/mastodon_profile_screen.dart';
import 'package:xta/plugins/mastodon/mastodon_store.dart';
import 'package:xta/ui/errors.dart';
import 'package:xta/utils/urls.dart';

/// One Fediverse status and its public replies, read through the home instance.
class MastodonThreadScreen extends StatefulWidget {
  final MastodonPost post;

  const MastodonThreadScreen({super.key, required this.post});

  @override
  State<MastodonThreadScreen> createState() => _MastodonThreadScreenState();
}

class _MastodonThreadScreenState extends State<MastodonThreadScreen> {
  late MastodonPost _status = widget.post;
  List<MastodonPost> _ancestors = const [];
  List<MastodonPost> _descendants = const [];
  Object? _error;
  var _loading = true;

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
    final client = context.read<MastodonClient>();
    final configured = mastodonConfiguredInstances(prefs);
    final candidates = mastodonInstanceCandidates(_status.acct, configured: configured);

    try {
      final thread = await client.fetchThreadAnywhere(candidates, _status);
      if (!mounted) return;
      setState(() {
        _status = thread.status;
        _ancestors = thread.ancestors;
        _descendants = thread.descendants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Still show the card we already had — leaving for the browser is opt-in.
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _openBrowser() => openUri(context, _status.url);

  void _openProfile(String acct) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MastodonProfileScreen(acct: acct)));
  }

  void _openPost(MastodonPost post) {
    if (post.id == _status.id && post.url == _status.url) {
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => MastodonThreadScreen(post: post)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_mastodon_title),
        actions: [
          IconButton(
            tooltip: l10n.open_in_browser,
            onPressed: _openBrowser,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(l10n),
      ),
    );
  }

  Widget _body(L10n l10n) {
    if (_loading && _ancestors.isEmpty && _descendants.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          MastodonPostCard(
            post: _status,
            showSourceBadge: false,
            openOnTap: false,
            onAuthorTap: () => _openProfile(_status.acct),
            onOpenBrowser: _openBrowser,
          ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final ancestor in _ancestors)
          MastodonPostCard(
            post: ancestor,
            showSourceBadge: false,
            onOpen: () => _openPost(ancestor),
            onAuthorTap: () => _openProfile(ancestor.acct),
            onOpenBrowser: () => openUri(context, ancestor.url),
          ),
        MastodonPostCard(
          post: _status,
          showSourceBadge: false,
          openOnTap: false,
          onAuthorTap: () => _openProfile(_status.acct),
          onOpenBrowser: _openBrowser,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FullPageErrorWidget(
              error: _error,
              stackTrace: null,
              prefix: mastodonErrorMessage(l10n, _error!),
              onRetry: _load,
            ),
          ),
        for (final reply in _descendants)
          MastodonPostCard(
            post: reply,
            showSourceBadge: false,
            onOpen: () => _openPost(reply),
            onAuthorTap: () => _openProfile(reply.acct),
            onOpenBrowser: () => openUri(context, reply.url),
          ),
      ],
    );
  }
}
