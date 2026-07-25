import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/group_identity.dart';

/// The feed title as a button that opens a group picker, so you can hop between
/// groups without going back to the Groups tab.
class GroupSwitcherTitle extends StatelessWidget {
  final String name;
  final String currentGroupId;
  final ValueChanged<SubscriptionGroup> onSwitch;

  const GroupSwitcherTitle({
    super.key,
    required this.name,
    required this.currentGroupId,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: L10n.of(context).switch_group,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: () => showGroupSwitcher(context, currentGroupId: currentGroupId, onSwitch: onSwitch),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 20, color: theme.appBarTheme.foregroundColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lists the groups in the order the Groups tab shows them (pinned first), with
/// the current one marked. Picking one calls [onSwitch].
Future<void> showGroupSwitcher(
  BuildContext context, {
  required String currentGroupId,
  required ValueChanged<SubscriptionGroup> onSwitch,
}) {
  final groupsModel = context.read<GroupsModel>();

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return ScopedBuilder<GroupsModel, List<SubscriptionGroup>>(
        store: groupsModel,
        onState: (_, groups) {
          if (groups.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Text(L10n.of(sheetContext).no_subscription_groups_yet),
            );
          }

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final isCurrent = group.id == currentGroupId;

                return ListTile(
                  leading: GroupMark.forGroup(group, size: 36),
                  title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(L10n.of(context).subscription_group_member_count(group.numberOfMembers)),
                  trailing: isCurrent ? const Icon(Icons.check) : (group.pinned ? const Icon(Icons.push_pin, size: 16) : null),
                  selected: isCurrent,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (!isCurrent) {
                      onSwitch(group);
                    }
                  },
                );
              },
            ),
          );
        },
      );
    },
  );
}
