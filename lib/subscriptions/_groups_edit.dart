import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/users_model.dart';
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
