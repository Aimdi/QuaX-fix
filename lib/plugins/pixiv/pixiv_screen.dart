import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';
import 'package:xta/plugins/pixiv/pixiv_grid.dart';
import 'package:xta/plugins/pixiv/pixiv_mute_store.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';
import 'package:xta/plugins/pixiv/pixiv_search_screen.dart';
import 'package:xta/plugins/pixiv/pixiv_settings.dart';
import 'package:xta/plugins/pixiv/pixiv_store.dart';
import 'package:xta/ui/errors.dart';

/// Pixez-style Pixiv home: Following / Ranking / Bookmarks + search.
class PixivScreen extends StatefulWidget {
  final ScrollController scrollController;

  const PixivScreen({super.key, required this.scrollController});

  @override
  State<PixivScreen> createState() => _PixivScreenState();
}

class _PixivScreenState extends State<PixivScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final PixivIllustListStore _ranking;
  late final PixivIllustListStore _bookmarks;
  var _signingIn = false;
  var _rankingMode = 'day';
  var _bookmarksRestrict = 'public';

  static const _rankingModes = [
    'day',
    'week',
    'month',
    'day_male',
    'day_female',
    'week_rookie',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      _ensureTabLoaded(_tabs.index);
    });
    final mute = context.read<PixivMuteStore>();
    _ranking = PixivIllustListStore(
      ({nextUrl}) => context.read<PixivClient>().ranking(
        mode: _rankingMode,
        nextUrl: nextUrl,
      ),
      filter: mute.filter,
    );
    _bookmarks = PixivIllustListStore(
      _bookmarksLoader(_bookmarksRestrict),
      filter: mute.filter,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await mute.load();
      if (!mounted) return;
      final prefs = PrefService.of(context, listen: false);
      final hasToken = (prefs.get<String>(optionPluginPixivRefreshToken) ?? '')
          .trim()
          .isNotEmpty;
      if (hasToken) {
        context.read<PixivFeedStore>().refresh();
      }
    });
  }

  PixivIllustPageLoader _bookmarksLoader(String restrict) {
    return ({nextUrl}) async {
      final client = context.read<PixivClient>();
      var userId = client.storedUserId;
      if (userId == null) {
        final user = await client.verify();
        userId = user.id;
      }
      return client.bookmarks(
        userId: userId,
        restrict: restrict,
        nextUrl: nextUrl,
      );
    };
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ranking.destroy();
    _bookmarks.destroy();
    super.dispose();
  }

  void _ensureTabLoaded(int index) {
    final prefs = PrefService.of(context, listen: false);
    if ((prefs.get<String>(optionPluginPixivRefreshToken) ?? '')
        .trim()
        .isEmpty) {
      return;
    }
    switch (index) {
      case 0:
        if (context.read<PixivFeedStore>().state.isEmpty) {
          context.read<PixivFeedStore>().refresh();
        }
      case 1:
        if (_ranking.state.isEmpty) {
          _ranking.refresh();
        }
      case 2:
        if (_bookmarks.state.isEmpty) {
          _bookmarks.refresh();
        }
    }
  }

  Future<void> _changeRankingMode(String mode) async {
    if (mode == _rankingMode) return;
    setState(() => _rankingMode = mode);
    _ranking.useLoader(
      ({nextUrl}) =>
          context.read<PixivClient>().ranking(mode: mode, nextUrl: nextUrl),
    );
    await _ranking.refresh();
  }

  Future<void> _changeBookmarksRestrict(String restrict) async {
    if (restrict == _bookmarksRestrict) return;
    setState(() => _bookmarksRestrict = restrict);
    _bookmarks.useLoader(_bookmarksLoader(restrict));
    await _bookmarks.refresh();
  }

  String _rankingLabel(L10n l10n, String mode) => switch (mode) {
    'week' => l10n.plugin_pixiv_ranking_week,
    'month' => l10n.plugin_pixiv_ranking_month,
    'day_male' => l10n.plugin_pixiv_ranking_day_male,
    'day_female' => l10n.plugin_pixiv_ranking_day_female,
    'week_rookie' => l10n.plugin_pixiv_ranking_rookie,
    _ => l10n.plugin_pixiv_ranking_day,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final prefs = PrefService.of(context);
    final hasToken = (prefs.get<String>(optionPluginPixivRefreshToken) ?? '')
        .trim()
        .isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_pixiv_title),
        actions: [
          if (hasToken)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.search,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PixivSearchScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () async {
              final feed = context.read<PixivFeedStore>();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PixivSettingsScreen()),
              );
              if (!mounted) return;
              await feed.refresh();
              if (!mounted) return;
              _ensureTabLoaded(_tabs.index);
            },
          ),
        ],
        bottom: hasToken
            ? TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: l10n.plugin_pixiv_tab_following),
                  Tab(text: l10n.plugin_pixiv_tab_ranking),
                  Tab(text: l10n.plugin_pixiv_tab_bookmarks),
                ],
              )
            : null,
      ),
      body: !hasToken
          ? _signInBody(l10n)
          : TabBarView(
              controller: _tabs,
              children: [
                _feedTab(
                  store: context.read<PixivFeedStore>(),
                  empty: l10n.plugin_pixiv_empty,
                ),
                _rankingTab(l10n),
                _bookmarksTab(l10n),
              ],
            ),
    );
  }

  Widget _signInBody(L10n l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.plugin_pixiv_not_configured, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _signingIn
                  ? null
                  : () async {
                      setState(() => _signingIn = true);
                      try {
                        final feed = context.read<PixivFeedStore>();
                        await runPixivSignIn(context);
                        if (mounted) {
                          setState(() {});
                          await feed.refresh();
                        }
                      } finally {
                        if (mounted) setState(() => _signingIn = false);
                      }
                    },
              child: _signingIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.plugin_pixiv_sign_in),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankingTab(L10n l10n) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              for (final mode in _rankingModes) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_rankingLabel(l10n, mode)),
                    selected: _rankingMode == mode,
                    onSelected: (_) => _changeRankingMode(mode),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _feedTab(
            store: _ranking,
            empty: l10n.plugin_pixiv_ranking_empty,
          ),
        ),
      ],
    );
  }

  Widget _bookmarksTab(L10n l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              ChoiceChip(
                label: Text(l10n.plugin_pixiv_bookmarks_public),
                selected: _bookmarksRestrict == 'public',
                onSelected: (_) => _changeBookmarksRestrict('public'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(l10n.plugin_pixiv_bookmarks_private),
                selected: _bookmarksRestrict == 'private',
                onSelected: (_) => _changeBookmarksRestrict('private'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _feedTab(
            store: _bookmarks,
            empty: l10n.plugin_pixiv_bookmarks_empty,
          ),
        ),
      ],
    );
  }

  Widget _feedTab({
    required PixivIllustListStore store,
    required String empty,
  }) {
    final l10n = L10n.of(context);
    return ScopedBuilder<PixivIllustListStore, List<PixivIllust>>.transition(
      store: store,
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onError: (context, error) => Padding(
        padding: const EdgeInsets.all(24),
        child: FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: pixivErrorMessage(l10n, error ?? Exception()),
          onRetry: store.refresh,
        ),
      ),
      onState: (context, illusts) {
        if (illusts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(empty, textAlign: TextAlign.center),
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
              store.loadMore();
            }
            return false;
          },
          child: PixivIllustGrid(
            illusts: illusts,
            scrollController: store == context.read<PixivFeedStore>()
                ? widget.scrollController
                : null,
            onRefresh: store.refresh,
            loadingMore: store.loadingMore,
          ),
        );
      },
    );
  }
}
