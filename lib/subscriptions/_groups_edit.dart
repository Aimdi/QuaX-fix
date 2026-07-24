import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/group_identity.dart';
import 'package:quax/subscriptions/group_mark_style.dart';
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
  String? emoji;
  int markStyle = GroupMarkStyle.auto;
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
          emoji = group.emoji;
          markStyle = group.markStyle;
          members = group.members;
          orderedSubscriptions = [
            ...subscriptions.where((s) => group.members.contains(s.id)),
            ...subscriptions.where((s) => !group.members.contains(s.id)),
          ];
        }));
  }

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
                      leading: GroupMark.forGroup(g, size: 32),
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

  Future<void> _pickEmoji() async {
    final controller = TextEditingController(text: emoji ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = L10n.of(context);
        return AlertDialog(
          title: Text(l10n.choose_emoji),
          content: TextField(
            controller: controller,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 40),
            decoration: InputDecoration(hintText: l10n.choose_emoji),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
    if (!mounted || result == null) return;
    setState(() {
      emoji = result.isEmpty ? null : result.characters.first;
      markStyle = GroupMarkStyle.emoji;
    });
  }

  Future<void> _pickIcon() async {
    final selected = await showDialog<({String key, IconData data})>(
      context: context,
      builder: (context) {
        final l10n = L10n.of(context);
        return AlertDialog(
          title: Text(l10n.choose_icon),
          content: SizedBox(
            width: 320,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: curatedGroupIcons.length,
              itemBuilder: (context, index) {
                final entry = curatedGroupIcons[index];
                return IconButton(
                  onPressed: () => Navigator.pop(context, entry),
                  icon: Icon(entry.data),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      icon = serializeCuratedGroupIcon(selected.key, selected.data);
      markStyle = GroupMarkStyle.symbol;
    });
  }

  Future<void> _onMarkStyleSelected(Set<int> selection) async {
    final next = selection.first;
    if (next == GroupMarkStyle.emoji) {
      await _pickEmoji();
      return;
    }
    if (next == GroupMarkStyle.symbol) {
      await _pickIcon();
      return;
    }
    setState(() {
      markStyle = GroupMarkStyle.auto;
      emoji = null;
    });
  }

  Widget _markPreview(BuildContext context) {
    final seed = color ?? hashedSeedColor(name ?? '');
    return GroupMark(
      name: name ?? '',
      seed: seed,
      emoji: emoji,
      icon: icon,
      markStyle: markStyle,
      size: 40,
    );
  }

  @override
  Widget build(BuildContext context) {
    var subscriptionsModel = context.read<SubscriptionsModel>();

    var group = _group;
    if (group == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final l10n = L10n.of(context);
    final isPinned = widget.id != null &&
        context.read<GroupsModel>().state.any((g) => g.id == widget.id && g.pinned);

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
        child: Text(l10n.toggle_all),
      ),
      if (widget.id != null)
        TextButton(
          onPressed: () async {
            final groupsModel = context.read<GroupsModel>();
            await groupsModel.toggleGroupPinned(widget.id!, !isPinned);
            if (mounted) setState(() {});
          },
          child: Text(isPinned ? l10n.unpin : l10n.pin),
        ),
      if (widget.id != null)
        TextButton(
          onPressed: () => _openMergeSheet(context),
          child: Text(l10n.merge_into),
        ),
      TextButton(
        onPressed: id == null ? null : () => openDeleteSubscriptionGroupDialog(id!, name!),
        child: Text(l10n.delete),
      ),
    ];
    List<Widget> buttonsLst2 = [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.cancel),
      ),
      Builder(builder: (context) {
        onPressed() async {
          if (_formKey.currentState!.validate()) {
            await context.read<GroupsModel>().saveGroup(
                  id,
                  name!,
                  icon,
                  color,
                  members,
                  emoji: emoji,
                  markStyle: markStyle,
                );

            Navigator.pop(context);
          }
        }

        return TextButton(
          onPressed: onPressed,
          child: Text(l10n.ok),
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
                children: [
                  _markPreview(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: group.name,
                      decoration: InputDecoration(
                        border: const UnderlineInputBorder(),
                        hintText: l10n.name,
                      ),
                      onChanged: (value) => setState(() {
                        name = value;
                      }),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.please_enter_a_name;
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
                              title: Text(l10n.pick_a_color),
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
                                  child: Text(l10n.cancel),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                TextButton(
                                  child: Text(l10n.ok),
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
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.group_mark_style_label, style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: GroupMarkStyle.auto, label: Text(l10n.group_mark_style_auto)),
                  ButtonSegment(value: GroupMarkStyle.emoji, label: Text(l10n.group_mark_style_emoji)),
                  ButtonSegment(value: GroupMarkStyle.symbol, label: Text(l10n.group_mark_style_icon)),
                ],
                selected: {
                  markStyle == GroupMarkStyle.emoji
                      ? GroupMarkStyle.emoji
                      : markStyle == GroupMarkStyle.symbol
                          ? GroupMarkStyle.symbol
                          : GroupMarkStyle.auto,
                },
                onSelectionChanged: _onMarkStyleSelected,
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: orderedSubscriptions.length,
                  itemBuilder: (context, index) {
                    var subscription = orderedSubscriptions[index];

                    var subtitle =
                        subscription is SearchSubscription ? L10n.current.search_term : '@${subscription.screenName}';

                    var avatar = subscription is SearchSubscription
                        ? const SizedBox(width: 48, child: Icon(Icons.search))
                        : UserAvatar(uri: subscription.profileImageUrlHttps);

                    return CheckboxListTile(
                      dense: true,
                      secondary: avatar,
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
