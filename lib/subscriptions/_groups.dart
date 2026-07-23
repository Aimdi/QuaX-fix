import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/_group_list_item.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:provider/provider.dart';

Future openSubscriptionGroupDialog(BuildContext context, String? id, String name, String icon) {
  return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: SubscriptionGroupEditDialog(id: id, name: name, icon: icon),
          ),
        );
      });
}

/// The Groups tab: a dense list of group rows with search, pinning,
/// drag-to-reorder (in custom sort mode) and swipe actions.
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

  Widget _swipeBackground(BuildContext context, {required bool alignEnd, required IconData icon}) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon),
    );
  }

  Future<bool?> _confirmDeleteGroup(BuildContext context, SubscriptionGroup group) {
    return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(L10n.of(context).are_you_sure),
              content: Text(L10n.of(context)
                  .are_you_sure_you_want_to_delete_the_subscription_group_name_of_group(group.name)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L10n.of(context).no)),
                TextButton(onPressed: () => Navigator.pop(context, true), child: Text(L10n.of(context).yes)),
              ],
            ));
  }

  // Swipe towards the end deletes (after confirmation); swipe from the start
  // toggles the pin without dismissing the row.
  Widget _buildSwipeableRow(BuildContext context, SubscriptionGroup group) {
    final model = context.read<GroupsModel>();
    return Dismissible(
      key: ValueKey(group.id),
      background: _swipeBackground(context,
          alignEnd: false, icon: group.pinned ? Icons.push_pin_outlined : Icons.push_pin),
      secondaryBackground: _swipeBackground(context, alignEnd: true, icon: Icons.delete_outline),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await model.toggleGroupPinned(group.id, !group.pinned);
          return false;
        }
        return await _confirmDeleteGroup(context, group) ?? false;
      },
      onDismissed: (_) => model.deleteGroup(group.id),
      child: GroupListItem(
        group: group,
        onLongPress: () => openSubscriptionGroupDialog(context, group.id, group.name, group.icon),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<SubscriptionGroup> groups) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: groups.length,
      itemBuilder: (context, index) => _buildSwipeableRow(context, groups[index]),
    );
  }

  Widget _buildReorderableList(BuildContext context, List<SubscriptionGroup> groups) {
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
          reorderIndex: index,
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
        final manualOrder = context.read<GroupsModel>().orderGroupsBy == 'position' && query.isEmpty;

        return Column(
          children: [
            if (state.length > 5) _buildSearchBar(context),
            Expanded(
              child: manualOrder ? _buildReorderableList(context, groups) : _buildList(context, groups),
            ),
          ],
        );
      },
    );
  }
}

/// Legacy embedded grid used by older layouts; prefer [SubscriptionGroupsPage].
class SubscriptionGroups extends StatefulWidget {
  final ScrollController scrollController;

  const SubscriptionGroups({super.key, required this.scrollController});

  @override
  State<SubscriptionGroups> createState() => _SubscriptionGroupsState();
}

class _SubscriptionGroupsState extends State<SubscriptionGroups> {
  @override
  Widget build(BuildContext context) {
    return SubscriptionGroupsPage(scrollController: widget.scrollController);
  }
}

class SubscriptionGroupEditDialog extends StatefulWidget {
  final String? id;
  final String name;
  final String icon;

  const SubscriptionGroupEditDialog({super.key, required this.id, required this.name, required this.icon});

  @override
  State<SubscriptionGroupEditDialog> createState() => _SubscriptionGroupEditDialogState();
}

class _SubscriptionGroupEditDialogState extends State<SubscriptionGroupEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  SubscriptionGroupEdit? _group;

  late String? id;
  late String? name;
  late String icon;
  Color? color;
  Set<String> members = <String>{};
  List<Subscription> orderedSubscriptions = [];

  @override
  void initState() {
    super.initState();

    setState(() {
      icon = widget.icon;
    });

    final subscriptions = context.read<SubscriptionsModel>().state;

    context.read<GroupsModel>().loadGroupEdit(widget.id).then((group) => setState(() {
          _group = group;

          id = group.id;
          name = group.name;
          icon = group.icon;
          color = group.color;
          members = group.members;
          orderedSubscriptions = [
            ...subscriptions.where((s) => group.members.contains(s.id)),
            ...subscriptions.where((s) => !group.members.contains(s.id)),
          ];
        }));
  }

  /// Picks another group and moves every member of this one into it, deleting
  /// this group afterwards. Resolves accidental duplicates like "Art (1)"/"Art (2)".
  Future<void> _openMergeSheet(BuildContext context) async {
    final groupsModel = context.read<GroupsModel>();
    final others = groupsModel.state.where((g) => g.id != widget.id).toList(growable: false);

    final target = await showModalBottomSheet<SubscriptionGroup>(
        context: context,
        builder: (sheetContext) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final g in others)
                    ListTile(
                      leading: Icon(g.iconData),
                      title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.pop(sheetContext, g),
                    ),
                ],
              ),
            ));

    if (target == null || !context.mounted) return;
    await groupsModel.mergeGroups(widget.id!, target.id);
    if (context.mounted) Navigator.pop(context);
  }

  void openDeleteSubscriptionGroupDialog(String id, String name) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(L10n.of(context).no),
              ),
              TextButton(
                onPressed: () async {
                  await context.read<GroupsModel>().deleteGroup(id);

                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(L10n.of(context).yes),
              ),
            ],
            title: Text(L10n.of(context).are_you_sure),
            content: Text(
              L10n.of(context).are_you_sure_you_want_to_delete_the_subscription_group_name_of_group(name),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    var subscriptionsModel = context.read<SubscriptionsModel>();

    var group = _group;
    if (group == null) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Widget> buttonsLst1 = [
      TextButton(
        onPressed: () {
          setState(() {
            if (members.isEmpty) {
              members = subscriptionsModel.state.map((e) => e.id).toSet();
            } else {
              members.clear();
            }
          });
        },
        child: Text(L10n.of(context).toggle_all),
      ),
      if (widget.id != null)
        TextButton(
          onPressed: () => _openMergeSheet(context),
          child: Text(L10n.of(context).merge_into),
        ),
      TextButton(
        onPressed: id == null ? null : () => openDeleteSubscriptionGroupDialog(id!, name!),
        child: Text(L10n.of(context).delete),
      ),
    ];
    List<Widget> buttonsLst2 = [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(L10n.of(context).cancel),
      ),
      Builder(builder: (context) {
        onPressed() async {
          if (_formKey.currentState!.validate()) {
            await context.read<GroupsModel>().saveGroup(id, name!, icon, color, members);

            Navigator.pop(context);
          }
        }

        return TextButton(
          onPressed: onPressed,
          child: Text(L10n.of(context).ok),
        );
      }),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: group.name,
                      decoration: InputDecoration(
                        border: const UnderlineInputBorder(),
                        hintText: L10n.of(context).name,
                      ),
                      onChanged: (value) => setState(() {
                        name = value;
                      }),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return L10n.of(context).please_enter_a_name;
                        }

                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.palette, color: color),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) {
                            var selectedColor = color;

                            return AlertDialog(
                              title: Text(L10n.of(context).pick_a_color),
                              content: SingleChildScrollView(
                                child: MaterialColorPicker(
                                  selectedColor: color ?? Colors.grey,
                                  onColorChange: (value) => setState(() {
                                    selectedColor = value;
                                  }),
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: Text(L10n.of(context).cancel),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                TextButton(
                                  child: Text(L10n.of(context).ok),
                                  onPressed: () {
                                    setState(() {
                                      color = selectedColor;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          });
                    },
                  ),
                  IconButton(
                    icon: Icon(deserializeIconData(icon)),
                    onPressed: () async {
                      var selectedIcon = await showIconPicker(
                        context,
                        configuration: SinglePickerConfiguration(
                            iconPackModes: [IconPack.material],
                            title: Text(L10n.of(context).pick_an_icon),
                            closeChild: Text(L10n.of(context).close),
                            searchHintText: L10n.of(context).search,
                            noResultsText: L10n.of(context).no_results_for),
                      );
                      if (selectedIcon != null) {
                        setState(() {
                          icon = jsonEncode(serializeIcon(selectedIcon));
                        });
                      }
                    },
                  )
                ],
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: orderedSubscriptions.length,
                  itemBuilder: (context, index) {
                    var subscription = orderedSubscriptions[index];

                    var subtitle =
                        subscription is SearchSubscription ? L10n.current.search_term : '@${subscription.screenName}';

                    var icon = subscription is SearchSubscription
                        ? const SizedBox(width: 48, child: Icon(Icons.search))
                        : UserAvatar(uri: subscription.profileImageUrlHttps);

                    return CheckboxListTile(
                      dense: true,
                      secondary: icon,
                      title: Text(subscription.name),
                      subtitle: Text(subtitle),
                      selected: members.contains(subscription.id),
                      value: members.contains(subscription.id),
                      onChanged: (v) => setState(() {
                        if (v == null || v == false) {
                          members.remove(subscription.id);
                        } else {
                          members.add(subscription.id);
                        }
                      }),
                    );
                  },
                ),
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  ...buttonsLst1,
                  ...buttonsLst2,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
