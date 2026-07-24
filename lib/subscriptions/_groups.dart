import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/_group_tile.dart';
import 'package:quax/subscriptions/_groups_edit.dart';
import 'package:quax/ui/errors.dart';
import 'package:provider/provider.dart';

export 'package:quax/subscriptions/_groups_edit.dart'
    show openSubscriptionGroupDialog, SubscriptionGroupEditDialog;

/// The Groups tab: a compact 3-column tonal-tile grid with search.
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
            onPressed: () => openSubscriptionGroupDialog(context, null, '', defaultGroupIcon),
            icon: const Icon(Icons.add),
            label: Text(L10n.of(context).create_subscription_group),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final hasQuery = _searchController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SearchBar(
        controller: _searchController,
        hintText: L10n.of(context).search,
        leading: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.search),
        ),
        trailing: hasQuery
            ? [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ]
            : null,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<SubscriptionGroup> groups) {
    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 4 / 3,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return SubscriptionGroupTile(
          key: ValueKey(group.id),
          group: group,
          onLongPress: () => openSubscriptionGroupDialog(context, group.id, group.name, group.icon),
        );
      },
    );
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
        final groups = query.isEmpty
            ? state
            : state.where((g) => g.name.toLowerCase().contains(query)).toList(growable: false);

        return Column(
          children: [
            if (state.length > 5) _buildSearchBar(context),
            Expanded(child: _buildGrid(context, groups)),
          ],
        );
      },
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
