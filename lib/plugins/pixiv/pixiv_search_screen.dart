import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';
import 'package:xta/plugins/pixiv/pixiv_grid.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';
import 'package:xta/plugins/pixiv/pixiv_settings.dart';
import 'package:xta/plugins/pixiv/pixiv_store.dart';
import 'package:xta/plugins/pixiv/pixiv_user_screen.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';
import 'package:xta/ui/errors.dart';

/// Tag / keyword / user search — Pixez's second home.
class PixivSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const PixivSearchScreen({super.key, this.initialQuery});

  @override
  State<PixivSearchScreen> createState() => _PixivSearchScreenState();
}

class _PixivSearchScreenState extends State<PixivSearchScreen> with SingleTickerProviderStateMixin {
  late final TextEditingController _query;
  late final TabController _tabs;
  late final PixivIllustListStore _illusts;
  List<PixivUser> _users = const [];
  String? _usersNext;
  Object? _usersError;
  var _usersLoading = false;
  var _searched = false;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery ?? '');
    _tabs = TabController(length: 2, vsync: this);
    _illusts = PixivIllustListStore(({nextUrl}) {
      return context.read<PixivClient>().searchIllust(_query.text, nextUrl: nextUrl);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if ((widget.initialQuery ?? '').trim().isNotEmpty) {
        _search();
      }
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _tabs.dispose();
    _illusts.destroy();
    super.dispose();
  }

  Future<void> _search() async {
    final word = _query.text.trim();
    if (word.isEmpty) {
      return;
    }
    final client = context.read<PixivClient>();
    FocusScope.of(context).unfocus();
    setState(() {
      _searched = true;
      _usersError = null;
      _usersLoading = true;
      _users = const [];
      _usersNext = null;
    });
    await _illusts.refresh();
    try {
      final page = await client.searchUsers(word);
      if (!mounted) return;
      setState(() {
        _users = page.users;
        _usersNext = page.nextUrl;
        _usersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = e;
        _usersLoading = false;
      });
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_usersLoading || _usersNext == null || _usersNext!.isEmpty) {
      return;
    }
    setState(() => _usersLoading = true);
    try {
      final page = await context.read<PixivClient>().searchUsers(_query.text, nextUrl: _usersNext);
      if (!mounted) return;
      setState(() {
        _users = [..._users, ...page.users];
        _usersNext = page.nextUrl;
        _usersLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          autofocus: (widget.initialQuery ?? '').isEmpty,
          decoration: InputDecoration(
            hintText: l10n.plugin_pixiv_search_hint,
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            tooltip: l10n.search,
            onPressed: _search,
            icon: const Icon(Icons.search),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.plugin_pixiv_tab_illusts),
            Tab(text: l10n.plugin_pixiv_tab_users),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _illustTab(l10n),
          _usersTab(l10n),
        ],
      ),
    );
  }

  Widget _illustTab(L10n l10n) {
    if (!_searched) {
      return Center(child: Text(l10n.plugin_pixiv_search_prompt, textAlign: TextAlign.center));
    }

    return ScopedBuilder<PixivIllustListStore, List<PixivIllust>>.transition(
      store: _illusts,
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onError: (context, error) => Padding(
        padding: const EdgeInsets.all(24),
        child: FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: pixivErrorMessage(l10n, error ?? Exception()),
          onRetry: _search,
        ),
      ),
      onState: (context, illusts) {
        if (illusts.isEmpty) {
          return Center(child: Text(l10n.plugin_pixiv_search_empty, textAlign: TextAlign.center));
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
              _illusts.loadMore();
            }
            return false;
          },
          child: PixivIllustGrid(
            illusts: illusts,
            onRefresh: _illusts.refresh,
            loadingMore: _illusts.loadingMore,
          ),
        );
      },
    );
  }

  Widget _usersTab(L10n l10n) {
    if (!_searched) {
      return Center(child: Text(l10n.plugin_pixiv_search_prompt, textAlign: TextAlign.center));
    }
    if (_usersLoading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null && _users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: FullPageErrorWidget(
          error: _usersError,
          stackTrace: null,
          prefix: pixivErrorMessage(l10n, _usersError!),
          onRetry: _search,
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(child: Text(l10n.plugin_pixiv_search_empty, textAlign: TextAlign.center));
    }

    final theme = Theme.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
          _loadMoreUsers();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: _users.length + (_usersLoading ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final user = _users[index];
          final avatar = user.avatarUrl;
          return ListTile(
            leading: ClipOval(
              child: avatar == null
                  ? FallbackAvatar(
                      seed: '${user.id}',
                      displayName: user.name,
                      size: 44,
                      accent: theme.colorScheme.primary,
                    )
                  : ExtendedImage.network(
                      avatar,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      headers: pixivImageHeaders,
                    ),
            ),
            title: Text(user.name),
            subtitle: Text('@${user.account}'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PixivUserScreen(userId: user.id)),
            ),
          );
        },
      ),
    );
  }
}
