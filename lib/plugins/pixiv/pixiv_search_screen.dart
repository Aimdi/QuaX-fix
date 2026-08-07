import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';
import 'package:xta/plugins/pixiv/pixiv_grid.dart';
import 'package:xta/plugins/pixiv/pixiv_illust_screen.dart';
import 'package:xta/plugins/pixiv/pixiv_image.dart';
import 'package:xta/plugins/pixiv/pixiv_links.dart';
import 'package:xta/plugins/pixiv/pixiv_mute_store.dart';
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

class _PixivSearchScreenState extends State<PixivSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _query;
  late final TabController _tabs;
  late final PixivIllustListStore _illusts;
  List<PixivUser> _users = const [];
  String? _usersNext;
  Object? _usersError;
  var _usersLoading = false;
  var _searched = false;
  var _searchTarget = 'partial_match_for_tags';
  var _sort = 'date_desc';

  static const _searchTargets = [
    'partial_match_for_tags',
    'exact_match_for_tags',
    'title_and_caption',
  ];
  static const _sorts = ['date_desc', 'popular_desc'];

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery ?? '');
    _tabs = TabController(length: 2, vsync: this);
    _illusts = PixivIllustListStore(({nextUrl}) {
      return context.read<PixivClient>().searchIllust(
        _query.text,
        searchTarget: _searchTarget,
        sort: _sort,
        nextUrl: nextUrl,
      );
    }, filter: context.read<PixivMuteStore>().filter);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<PixivSearchHistoryStore>().load();
      if (!mounted) return;
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
    final link = parsePixivLink(word);
    if (link != null) {
      await _openLink(link);
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
    await context.read<PixivSearchHistoryStore>().add(word);
    if (!mounted) return;
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

  Future<void> _openLink(PixivLinkRef link) async {
    final navigator = Navigator.of(context);
    if (link case PixivUserLinkRef(:final id)) {
      await navigator.push(
        MaterialPageRoute(builder: (_) => PixivUserScreen(userId: id)),
      );
      return;
    }

    final client = context.read<PixivClient>();
    final messenger = ScaffoldMessenger.of(context);
    final message = L10n.of(context).plugin_pixiv_open_link_failed;
    try {
      final illust = await client.illustDetail(link.id);
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(builder: (_) => PixivIllustScreen(illust: illust)),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_usersLoading || _usersNext == null || _usersNext!.isEmpty) {
      return;
    }
    setState(() => _usersLoading = true);
    try {
      final page = await context.read<PixivClient>().searchUsers(
        _query.text,
        nextUrl: _usersNext,
      );
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
        children: [_illustTab(l10n), _usersTab(l10n)],
      ),
    );
  }

  Widget _illustTab(L10n l10n) {
    if (!_searched) {
      return _searchHome(l10n);
    }

    return Column(
      children: [
        _searchControls(l10n),
        Expanded(
          child:
              ScopedBuilder<PixivIllustListStore, List<PixivIllust>>(
                store: _illusts,
                onLoading: (_) {
                  if (_illusts.state.isNotEmpty) {
                    return PixivIllustGrid(
                      illusts: _illusts.state,
                      onRefresh: _illusts.refresh,
                      loadingMore: _illusts.loadingMore,
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
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
                    return Center(
                      child: Text(
                        l10n.plugin_pixiv_search_empty,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels > n.metrics.maxScrollExtent - 1400) {
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
              ),
        ),
      ],
    );
  }

  Widget _searchHome(L10n l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ScopedBuilder<PixivSearchHistoryStore, List<String>>.transition(
          store: context.read<PixivSearchHistoryStore>(),
          onState: (context, history) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.plugin_pixiv_search_prompt,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.plugin_pixiv_search_history,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              if (history.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.plugin_pixiv_search_history_empty),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final query in history)
                        GestureDetector(
                          onLongPress: () => context
                              .read<PixivSearchHistoryStore>()
                              .remove(query),
                          child: ActionChip(
                            label: Text(query),
                            onPressed: () {
                              _query.text = query;
                              _search();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchControls(L10n l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          for (final target in _searchTargets)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(_targetLabel(l10n, target)),
                selected: _searchTarget == target,
                onSelected: (_) => _changeSearchTarget(target),
              ),
            ),
          const SizedBox(width: 8),
          for (final sort in _sorts)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(_sortLabel(l10n, sort)),
                selected: _sort == sort,
                onSelected: (_) => _changeSort(sort),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _changeSearchTarget(String target) async {
    if (target == _searchTarget) return;
    setState(() => _searchTarget = target);
    if (_searched) await _search();
  }

  Future<void> _changeSort(String sort) async {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    if (_searched) await _search();
  }

  String _targetLabel(L10n l10n, String target) => switch (target) {
    'exact_match_for_tags' => l10n.plugin_pixiv_search_target_exact,
    'title_and_caption' => l10n.plugin_pixiv_search_target_title,
    _ => l10n.plugin_pixiv_search_target_partial,
  };

  String _sortLabel(L10n l10n, String sort) => switch (sort) {
    'popular_desc' => l10n.plugin_pixiv_search_sort_popular,
    _ => l10n.plugin_pixiv_search_sort_newest,
  };

  Widget _usersTab(L10n l10n) {
    if (!_searched) {
      return _searchHome(l10n);
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
      return Center(
        child: Text(
          l10n.plugin_pixiv_search_empty,
          textAlign: TextAlign.center,
        ),
      );
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
                  : SizedBox(
                      width: 44,
                      height: 44,
                      child: PixivNetworkImage(
                        url: avatar,
                        fit: BoxFit.cover,
                        cacheWidth:
                            (44 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                        cacheHeight:
                            (44 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                      ),
                    ),
            ),
            title: Text(user.name),
            subtitle: Text('@${user.account}'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PixivUserScreen(userId: user.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
