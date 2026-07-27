import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/group/group_tree.dart';
import 'package:quax/subscriptions/_group_list_item.dart';
import 'package:quax/subscriptions/_groups_edit.dart';
import 'package:quax/subscriptions/widgets/group_tile.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/x_controls.dart';
import 'package:provider/provider.dart';
import 'package:quax/plugins/plugin.dart';
import 'package:quax/plugins/plugin_registry.dart';

export 'package:quax/subscriptions/_groups_edit.dart'
    show openSubscriptionGroupDialog, SubscriptionGroupEditDialog;

/// Tiles past this index appear without the entrance stagger.
const _staggerLimit = 12;

/// The Groups tab: a board of member-faced tiles with search, plus a
/// drag-to-reorder list while custom ordering is active.
class SubscriptionGroupsPage extends StatefulWidget {
  final ScrollController scrollController;

  const SubscriptionGroupsPage({super.key, required this.scrollController});

  @override
  State<SubscriptionGroupsPage> createState() => _SubscriptionGroupsPageState();
}

class _SubscriptionGroupsPageState extends State<SubscriptionGroupsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Icon(Icons.workspaces_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          L10n.of(context).no_subscription_groups_yet,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          L10n.of(context).no_subscription_groups_description,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            style: xPrimaryPillStyle(context),
            onPressed: () => openSubscriptionGroupDialog(context, null, '', defaultGroupIcon),
            icon: const Icon(Icons.add),
            label: Text(L10n.of(context).create_subscription_group),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: XSearchField(
        controller: _searchController,
        hintText: L10n.of(context).search,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  /// The board: a compact grid of member-faced tiles.
  Widget _buildBoard(BuildContext context, List<SubscriptionGroup> groups, {required bool animate}) {
    final prefs = PrefService.of(context);
    final columns = (prefs.get<int>(optionSubscriptionGroupsColumns) ?? 2).clamp(2, 3);

    // Large text needs taller tiles, or the title and count would squeeze the
    // avatar mosaic out of the tile entirely.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0);
    final baseRatio = columns == 2 ? 168 / 132 : 1.0;
    final aspectRatio = baseRatio / (1 + (textScale - 1) * 0.55);

    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      // Build a row ahead so avatars decode before they scroll into view.
      scrollCacheExtent: const ScrollCacheExtent.pixels(300),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: aspectRatio,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final tile = GroupTile(
          key: ValueKey(group.id),
          group: group,
          animate: animate,
          onTap: () => Navigator.pushNamed(context, routeGroup,
              arguments: GroupScreenArguments(id: group.id, name: group.name)),
          onLongPress: () => openSubscriptionGroupDialog(context, group.id, group.name, group.icon),
        );

        // Only the first screenful is staggered; tiles scrolled into view later
        // appear immediately rather than animating under the user's thumb.
        if (!animate || index >= _staggerLimit) {
          return tile;
        }
        return _StaggeredEntrance(delay: Duration(milliseconds: 20 * index), child: tile);
      },
    );
  }

  Widget _buildReorderableList(BuildContext context, List<SubscriptionGroup> groups,
      {required bool canReorder, Map<String, int> depths = const {}}) {
    return ReorderableListView.builder(
      scrollController: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      buildDefaultDragHandles: false,
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return GroupListItem(
          key: ValueKey(group.id),
          group: group,
          depth: depths[group.id] ?? 0,
          // No handle means no drag: rearranging a name-sorted or filtered list
          // would write an order the reader cannot see.
          reorderIndex: canReorder ? index : null,
          onLongPress: () => openSubscriptionGroupDialog(context, group.id, group.name, group.icon),
        );
      },
      onReorderItem: (oldIndex, newIndex) {
        final ids = groups.map((g) => g.id).toList();
        ids.insert(newIndex, ids.removeAt(oldIndex));
        context.read<GroupsModel>().saveGroupPositions(ids);
      },
    );
  }

  /// Feeds a plugin provides, listed with the groups so they are reachable from
  /// where feeds live. Only shown once a plugin has given up its own home tab,
  /// otherwise the same feed would have two entry points.
  List<Widget> _pluginFeedRows(BuildContext context) {
    final prefs = PrefService.of(context);

    return [
      for (final plugin in builtInPlugins)
        if (plugin.isEnabled(prefs) && !plugin.showsHomeTab(prefs) && plugin.homeTabPrefKey != null)
          ListTile(
            leading: Icon(plugin.icon),
            title: Text(plugin.title(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _PluginFeedRoute(plugin: plugin)),
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<GroupsModel, List<SubscriptionGroup>>.transition(
      store: context.read<GroupsModel>(),
      onError: (_, error) => FullPageErrorWidget(
        error: error,
        stackTrace: null,
        prefix: L10n.of(context).unable_to_load_the_group,
        onRetry: () => context.read<GroupsModel>().reloadGroups(),
      ),
      onState: (_, state) {
        if (state.isEmpty) {
          return _buildEmptyState(context);
        }

        final query = _searchController.text.toLowerCase();
        var groups = query.isEmpty
            ? state
            : state.where((g) => g.name.toLowerCase().contains(query)).toList(growable: false);

        // A nested group sits under its parent rather than beside it — but it
        // is still shown. Hiding it made "put inside group" look like a delete.
        // While searching the order is left alone: the reader is looking for one
        // group and should find it wherever it lives.
        final parents = {for (final g in state) g.id: g.parentId};
        if (query.isEmpty) {
          final byId = {for (final g in groups) g.id: g};
          groups = groupsInTreeOrder(byId.keys, parents).map((id) => byId[id]!).toList(growable: false);
        }
        final prefs = PrefService.of(context);
        final animate = prefs.get<bool>(optionDisableAnimations) != true;
        final asList = prefs.get<String>(optionSubscriptionGroupsLayout) == subscriptionGroupsLayoutList;
        // Dragging tiles around a grid is far fiddlier than dragging rows, so
        // only the list carries drag handles — and only when the order it would
        // rearrange is the one being shown.
        final canReorder = context.read<GroupsModel>().orderGroupsBy == 'position' && query.isEmpty;
        // How far each group is indented, so a nested one reads as nested.
        final depths = {for (final g in groups) g.id: depthOf(g.id, parents)};

        return Column(
          children: [
            if (state.length > 5) _buildSearchBar(context),
            ..._pluginFeedRows(context),
            Expanded(
              child: asList
                  ? _buildReorderableList(context, groups, canReorder: canReorder, depths: depths)
                  : _buildBoard(context, groups, animate: animate),
            ),
          ],
        );
      },
    );
  }
}

/// Fades and lifts a tile into place once, shortly after first build.
class _StaggeredEntrance extends StatefulWidget {
  final Duration delay;
  final Widget child;

  const _StaggeredEntrance({required this.delay, required this.child});

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Legacy embed point; prefer [SubscriptionGroupsPage].
class SubscriptionGroups extends StatelessWidget {
  final ScrollController scrollController;

  const SubscriptionGroups({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return SubscriptionGroupsPage(scrollController: scrollController);
  }
}

/// Hosts a plugin's feed screen as a pushed route, for plugins that no longer
/// occupy a home tab. The screen brings its own app bar.
class _PluginFeedRoute extends StatefulWidget {
  final QuaxPlugin plugin;

  const _PluginFeedRoute({required this.plugin});

  @override
  State<_PluginFeedRoute> createState() => _PluginFeedRouteState();
}

class _PluginFeedRouteState extends State<_PluginFeedRoute> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.plugin.homeScreen(scrollController: _scrollController) ?? const SizedBox.shrink();
  }
}
