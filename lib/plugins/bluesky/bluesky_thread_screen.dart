import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/bluesky/bluesky_client.dart';
import 'package:xta/plugins/bluesky/bluesky_models.dart';
import 'package:xta/plugins/bluesky/bluesky_post_card.dart';
import 'package:xta/plugins/bluesky/bluesky_profile_screen.dart';
import 'package:xta/ui/errors.dart';
import 'package:xta/utils/urls.dart';

/// One Bluesky post and its public replies, read through the AppView.
class BlueskyThreadScreen extends StatefulWidget {
  final BlueskyPost post;

  const BlueskyThreadScreen({super.key, required this.post});

  @override
  State<BlueskyThreadScreen> createState() => _BlueskyThreadScreenState();
}

class _BlueskyThreadScreenState extends State<BlueskyThreadScreen> {
  late BlueskyPost _status = widget.post;
  List<BlueskyPost> _ancestors = const [];
  List<BlueskyPost> _replies = const [];
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

    final client = context.read<BlueskyClient>();
    try {
      final thread = await client.getPostThread(_status.uri);
      if (!mounted) return;
      setState(() {
        _status = thread.post;
        _ancestors = thread.ancestors;
        _replies = thread.replies;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _openBrowser() => openUri(context, _status.url);

  void _openProfile(String actor) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BlueskyProfileScreen(actor: actor)));
  }

  void _openPost(BlueskyPost post) {
    if (post.uri == _status.uri) {
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => BlueskyThreadScreen(post: post)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_bluesky_title),
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
    if (_loading && _ancestors.isEmpty && _replies.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          BlueskyPostCard(
            post: _status,
            showSourceBadge: false,
            openOnTap: false,
            onAuthorTap: () => _openProfile(_status.handle),
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
          BlueskyPostCard(
            post: ancestor,
            showSourceBadge: false,
            onOpen: () => _openPost(ancestor),
            onAuthorTap: () => _openProfile(ancestor.handle),
            onOpenBrowser: () => openUri(context, ancestor.url),
          ),
        BlueskyPostCard(
          post: _status,
          showSourceBadge: false,
          openOnTap: false,
          onAuthorTap: () => _openProfile(_status.handle),
          onOpenBrowser: _openBrowser,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FullPageErrorWidget(
              error: _error,
              stackTrace: null,
              prefix: blueskyErrorMessage(l10n, _error!),
              onRetry: _load,
            ),
          ),
        for (final reply in _replies)
          BlueskyPostCard(
            post: reply,
            showSourceBadge: false,
            onOpen: () => _openPost(reply),
            onAuthorTap: () => _openProfile(reply.handle),
            onOpenBrowser: () => openUri(context, reply.url),
          ),
      ],
    );
  }
}
