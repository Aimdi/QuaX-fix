import 'dart:convert';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_triple/flutter_triple.dart';

import 'package:xta/client/client.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/group/group_model.dart';
import 'package:xta/saved/likes_by_group.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/profile/media_grid/media_grid.dart';
import 'package:xta/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:xta/profile/profile.dart';
import 'package:xta/saved/folder_picker.dart';
import 'package:xta/saved/liked_tweet_model.dart';
import 'package:xta/saved/saved_cleanup.dart';
import 'package:xta/saved/saved_tab_order.dart';
import 'package:xta/saved/saved_tweet_folder_model.dart';
import 'package:xta/saved/saved_tweet_model.dart';
import 'package:xta/tweet/tweet.dart';
import 'package:xta/ui/errors.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class SavedScreen extends StatefulWidget {
  final ScrollController scrollController;
  final bool? showTitle;

  const SavedScreen({super.key, required this.scrollController, this.showTitle});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with AutomaticKeepAliveClientMixin<SavedScreen> {
  // Selected folder filter: savedTabAll, savedTabUnfiled, or a folder id.
  String _filter = savedTabAll;
  bool _mediaOnly = false;
  bool _searching = false;
  String _query = '';

  /// Whether likes are broken out by the group their author belongs to.
  bool _likesByGroup = false;

  /// Group membership and group names, read once so the breakdown does not
  /// query per like.
  List<SubscriptionGroupMember> _groupMembers = const [];
  List<SubscriptionGroup> _groups = const [];

  /// Focused when the search button opens the field, rather than by `autofocus`.
  ///
  /// This screen is kept alive, so the field's subtree is re-inserted whenever
  /// the folder strip or a filter chip rebuilds — with `autofocus` that raised
  /// the keyboard again each time, unasked.
  final FocusNode _searchFocusNode = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    context.read<SavedTweetModel>().listSavedTweets();
    context.read<SavedTweetFolderModel>().listFolders();
    context.read<LikedTweetModel>().listLikedTweets();
    _loadGroupMembership();
  }

  Future<void> _loadGroupMembership() async {
    final model = context.read<GroupsModel>();
    final members = await model.listGroupMembers();
    if (!mounted) return;

    setState(() {
      _groupMembers = members;
      _groups = model.state;
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  // If the selected tab is no longer reachable (folder deleted elsewhere, or its
  // built-in tab was hidden in settings), fall back to "All".
  void _reconcileFilter(List<SavedTweetFolder> folders, {required bool showUnfiled, required bool showFavorites}) {
    var reachable = _filter == savedTabAll ||
        (_filter == savedTabUnfiled && showUnfiled && folders.isNotEmpty) ||
        (_filter == savedTabFavorites && showFavorites) ||
        folders.any((f) => f.id == _filter);
    if (reachable) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _filter = savedTabAll);
      }
    });
  }

  Future<void> _refresh() async {
    // Silent reload: keeps the current list on screen while the RefreshIndicator
    // spinner runs, and swaps in the fresh data only once it is ready.
    if (_filter == savedTabFavorites) {
      await context.read<LikedTweetModel>().refreshLikedTweets();
    } else {
      await context.read<SavedTweetModel>().refreshSavedTweets();
    }
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Text(_query.isNotEmpty
                ? L10n.of(context).no_posts_match_your_search
                : switch (_filter) {
                    savedTabAll => L10n.of(context).you_have_not_saved_any_tweets_yet,
                    savedTabFavorites => L10n.of(context).no_liked_posts_yet,
                    _ => L10n.of(context).folder_is_empty,
                  }),
          ),
        ),
      ),
    );
  }

  /// Case-insensitive match of a stored tweet's JSON against the search query:
  /// post text (including long-post note text) plus author name and handle.
  bool _matchesQuery(String? content) {
    if (content == null) {
      return false;
    }
    final needle = _query.toLowerCase();
    try {
      final json = jsonDecode(content);
      final haystacks = [
        json['full_text'] as String?,
        json['text'] as String?,
        json['noteText'] as String?,
        json['user']?['name'] as String?,
        json['user']?['screen_name'] as String?,
      ];
      return haystacks.any((h) => h != null && h.toLowerCase().contains(needle));
    } catch (_) {
      return false;
    }
  }

  List<T> _applySearch<T>(List<T> items, String? Function(T) contentOf) {
    if (_query.isEmpty) {
      return items;
    }
    return items.where((e) => _matchesQuery(contentOf(e))).toList();
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: L10n.of(context).search_saved_posts,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
        ),
        onChanged: (value) => setState(() => _query = value.trim()),
      ),
    );
  }

  Widget _buildList({required int itemCount, required SavedTweetTile Function(int) tileAt}) {
    return ListView.builder(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      itemCount: itemCount,
      itemBuilder: (context, index) => tileAt(index),
    );
  }

  /// Media entries of the given saved posts, for the media-only grid.
  List<MediaGridItem> _mediaItemsOf(Iterable<String?> contents) {
    var chains = <TweetChain>[];
    for (var content in contents) {
      if (content == null) {
        continue;
      }
      var tweet = TweetWithCard.fromJson(jsonDecode(content));
      if (tweet.idStr == null) {
        continue;
      }
      chains.add(TweetChain(id: tweet.idStr!, tweets: [tweet], isPinned: false));
    }
    return mediaItemsFromChains(chains);
  }

  Widget _buildMediaGrid(Iterable<String?> contents, {required Future<void> Function(String id) onDelete}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: StaticMediaGrid(
        items: _mediaItemsOf(contents),
        emptyMessage: L10n.of(context).could_not_find_any_posts_with_media,
        onLongPressItem: (item) => _confirmRemoveFromGallery(item.tweetId, onDelete),
      ),
    );
  }

  // Long-pressing a tile in the saved gallery removes that post — handy for
  // clearing the dead "not available" ones without leaving gallery mode.
  Future<void> _confirmRemoveFromGallery(String id, Future<void> Function(String id) onDelete) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).are_you_sure),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L10n.of(context).cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(L10n.of(context).delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await onDelete(id);
    }
  }

  List<SavedTweet> _applyFilter(List<SavedTweet> tweets) {
    switch (_filter) {
      case savedTabAll:
        return tweets;
      case savedTabUnfiled:
        return tweets.where((e) => e.folderId == null).toList();
      default:
        return tweets.where((e) => e.folderId == _filter).toList();
    }
  }

  Widget _buildFolderStrip() {
    var prefs = PrefService.of(context, listen: false);
    var showAll = prefs.get<bool>(optionSavedShowAllTab) ?? true;
    var showUnfiled = prefs.get<bool>(optionSavedShowUnfiledTab) ?? true;
    var showFavorites = prefs.get<bool>(optionSavedShowFavoritesTab) ?? true;
    var storedOrder = prefs.get<String>(optionSavedTabOrder);

    return ScopedBuilder<SavedTweetFolderModel, List<SavedTweetFolder>>(
      store: context.read<SavedTweetFolderModel>(),
      onState: (context, folders) {
        // Reconcile before the empty check, otherwise deleting the last folder would
        // leave `_filter` stranded on a now-deleted id (the strip returns early).
        _reconcileFilter(folders, showUnfiled: showUnfiled, showFavorites: showFavorites);

        // With no folders, only show the strip when the Favorites tab is available to
        // switch to — otherwise there is nothing to switch between (just "All").
        if (folders.isEmpty && !showFavorites) {
          return const SizedBox.shrink();
        }

        var chips = <Widget>[];
        for (var token in orderedSavedTabs(folders, storedOrder)) {
          if (token == savedTabAll) {
            if (showAll) chips.add(_folderChip(label: L10n.of(context).all, value: savedTabAll));
          } else if (token == savedTabUnfiled) {
            // "Unfiled" only makes sense with folders — otherwise it duplicates "All".
            if (showUnfiled && folders.isNotEmpty) {
              chips.add(_folderChip(label: L10n.of(context).unfiled, value: savedTabUnfiled));
            }
          } else if (token == savedTabFavorites) {
            if (showFavorites) chips.add(_folderChip(label: L10n.of(context).favorites, value: savedTabFavorites));
          } else {
            var matches = folders.where((f) => f.id == token);
            if (matches.isNotEmpty) chips.add(_folderChip(label: matches.first.name, value: token));
          }
        }

        return SizedBox(
          height: 52,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: chips),
            ),
          ),
        );
      },
    );
  }

  Widget _folderChip({required String label, required String value}) {
    var isFolder = value != savedTabAll && value != savedTabUnfiled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onLongPress: isFolder ? () => _showFolderMenu(value, label) : null,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ChoiceChip(
            // Likes carry a chevron once they are the chip you are on: tapping
            // the chip shows them flat, the chevron breaks them out by the
            // group each author belongs to.
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (value == savedTabFavorites && _filter == savedTabFavorites) ...[
                  const SizedBox(width: 4),
                  Icon(_likesByGroup ? Icons.expand_less : Icons.expand_more, size: 18),
                ],
              ],
            ),
            selected: _filter == value,
            showCheckmark: false,
            shape: const StadiumBorder(),
            side: BorderSide.none,
            onSelected: (_) => setState(() {
              // A second tap on the likes chip toggles the breakdown; landing
              // on it for the first time always shows them flat.
              if (value == savedTabFavorites && _filter == savedTabFavorites) {
                _likesByGroup = !_likesByGroup;
              } else {
                _likesByGroup = false;
                _filter = value;
              }
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _showFolderMenu(String folderId, String label) async {
    var folderModel = context.read<SavedTweetFolderModel>();
    var matches = folderModel.state.where((f) => f.id == folderId);
    if (matches.isEmpty) {
      return;
    }
    var folder = matches.first;

    await HapticFeedback.lightImpact();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.edit_outlined),
              title: Text(L10n.of(sheetContext).rename),
              onTap: () {
                Navigator.pop(sheetContext);
                showCreateFolderDialog(context, folderModel, existing: folder);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.delete_outline),
              title: Text(L10n.of(sheetContext).delete),
              onTap: () async {
                Navigator.pop(sheetContext);
                var deleted = await showDeleteFolderDialog(context, folderModel, folder);
                if (deleted && mounted && _filter == folderId) {
                  setState(() => _filter = savedTabAll);
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.folder_copy_outlined),
              title: Text(L10n.of(sheetContext).manage_folders),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Navigator.pushNamed(context, routeSavedFolders);
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedBody(SavedTweetModel model) {
    return ScopedBuilder<SavedTweetModel, List<SavedTweet>>.transition(
      store: model,
      onError: (_, e) => FullPageErrorWidget(
        error: e,
        stackTrace: null,
        prefix: L10n.current.unable_to_load_the_tweets,
        onRetry: () => model.listSavedTweets(),
      ),
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onState: (_, data) {
        var filtered = _applySearch(_applyFilter(data), (SavedTweet e) => e.content);

        if (_mediaOnly && filtered.isNotEmpty) {
          return _buildMediaGrid(filtered.map((e) => e.content),
              onDelete: (id) => context.read<SavedTweetModel>().deleteSavedTweet(id));
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: filtered.isEmpty
              ? _buildEmptyState()
              : _buildList(
                  itemCount: filtered.length,
                  tileAt: (i) => SavedTweetTile(id: filtered[i].id, content: filtered[i].content)),
        );
      },
    );
  }

  /// Likes under one heading per group their author belongs to.
  ///
  /// One flat list with headings rather than a list of lists: the reader is
  /// still scrolling their likes, just with the feeds they came from marked.
  Widget _buildLikesByGroup(List<LikedTweet> likes) {
    final sections = likesByGroup<LikedTweet>(
      likes,
      authorOf: (like) => like.user,
      members: _groupMembers,
      groupIds: _groups.map((g) => g.id).toList(growable: false),
    );

    final nameOf = {for (final group in _groups) group.id: group.name};
    final rows = <Widget>[];
    for (final section in sections) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          section.isUngrouped ? L10n.of(context).likes_without_a_group : nameOf[section.groupId] ?? '',
          style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700),
        ),
      ));
      rows.addAll(section.items.map((like) => SavedTweetTile(id: like.id, content: like.content)));
    }

    return ListView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: rows,
    );
  }

  Widget _buildFavoritesBody() {
    var model = context.read<LikedTweetModel>();

    return ScopedBuilder<LikedTweetModel, List<LikedTweet>>.transition(
      store: model,
      onError: (_, e) => FullPageErrorWidget(
        error: e,
        stackTrace: null,
        prefix: L10n.current.unable_to_load_the_tweets,
        onRetry: () => model.listLikedTweets(),
      ),
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onState: (_, data) {
        var filtered = _applySearch(data, (LikedTweet e) => e.content);

        if (_mediaOnly && filtered.isNotEmpty) {
          return _buildMediaGrid(filtered.map((e) => e.content),
              onDelete: (id) => context.read<LikedTweetModel>().unlikeTweet(id));
        }

        if (_likesByGroup && filtered.isNotEmpty) {
          return RefreshIndicator(onRefresh: _refresh, child: _buildLikesByGroup(filtered));
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: filtered.isEmpty
              ? _buildEmptyState()
              : _buildList(
                  itemCount: filtered.length,
                  tileAt: (i) => SavedTweetTile(id: filtered[i].id, content: filtered[i].content)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var model = context.read<SavedTweetModel>();

    var prefs = PrefService.of(context, listen: false);

    return NestedScrollView(
      controller: widget.scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          if (widget.showTitle != false)
            SliverAppBar(
              pinned: false,
              snap: true,
              floating: true,
              title: Text(L10n.current.saved),
              actions: [
                IconButton(
                  isSelected: _searching,
                  icon: const Icon(Icons.search),
                  tooltip: L10n.current.search_saved_posts,
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    if (_searching) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
                    } else {
                      _query = '';
                      _searchFocusNode.unfocus();
                    }
                  }),
                ),
                IconButton(
                  isSelected: _mediaOnly,
                  icon: const Icon(Icons.photo_library_outlined),
                  selectedIcon: const Icon(Icons.photo_library),
                  tooltip: L10n.current.only_show_posts_with_media,
                  onPressed: () => setState(() => _mediaOnly = !_mediaOnly),
                ),
                IconButton(
                    icon: const Icon(Icons.folder_copy_outlined),
                    tooltip: L10n.current.manage_folders,
                    onPressed: () async {
                      await Navigator.pushNamed(context, routeSavedFolders);
                      if (mounted) {
                        setState(() {});
                      }
                    }),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: L10n.current.find_broken_bookmarks,
                  onPressed: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const BrokenBookmarksDialog(),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () async {
                      Navigator.pushNamed(context, routeSettings);
                    })
              ],
            )
        ];
      },
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider<TweetContextState>(
              create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive))),
        ],
        child: Column(
          children: [
            _buildFolderStrip(),
            if (_searching) _buildSearchField(),
            Expanded(
              child: _filter == savedTabFavorites ? _buildFavoritesBody() : _buildSavedBody(model),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedTweetTile extends StatefulWidget {
  final String id;
  final String? content;

  const SavedTweetTile({super.key, required this.id, this.content});

  @override
  State<SavedTweetTile> createState() => _SavedTweetTileState();
}

class _SavedTweetTileState extends State<SavedTweetTile> {
  // Decoded once per mount: the JSON of a saved post runs to tens of KB, and
  // decoding it on every build made scrolling the saved list a parsing loop.
  late TweetWithCard? _tweet = _decode();

  TweetWithCard? _decode() {
    final content = widget.content;
    if (content == null) {
      return null;
    }
    return TweetWithCard.fromJson(jsonDecode(content));
  }

  @override
  void didUpdateWidget(SavedTweetTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id || widget.content != oldWidget.content) {
      _tweet = _decode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tweet = _tweet;
    if (tweet == null) {
      // The tweet is probably too big to fit inside the cursor and has been
      // removed from the result set.
      return SavedTweetTooLarge(id: widget.id);
    }

    return TweetTile(key: Key(tweet.idStr!), tweet: tweet, clickable: true);
  }
}

class SavedTweetTooLarge extends StatelessWidget {
  final String id;

  const SavedTweetTooLarge({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading:
                  Icon(Icons.error_outline, color: Colors.red.harmonizeWith(Theme.of(context).colorScheme.primary)),
              title: Text(L10n.current.oops_something_went_wrong),
              subtitle: Text(L10n.current.saved_tweet_too_large),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedTweetTooLargeException implements Exception {
  final String id;

  SavedTweetTooLargeException(this.id);

  @override
  String toString() {
    return 'The saved tweet with the ID $id was too large';
  }
}
