import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/subscriptions/group_identity.dart';

/// Compact Groups-grid tile: color-tinted cell + tonal [GroupMark] chip.
/// Name/count stay on the surface (not on a saturated fill).
class SubscriptionGroupTile extends StatelessWidget {
  final SubscriptionGroup group;
  final VoidCallback? onLongPress;

  const SubscriptionGroupTile({super.key, required this.group, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final seed = groupSeedColor(group);
    final fill = tintedSurface(context, seed);
    final outlined = useGroupMarkOutline(context);
    final countLabel = l10n.subscription_group_member_count(group.numberOfMembers);
    final semanticsLabel = '${group.name}, $countLabel';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        shape: outlined
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
              )
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(
            context,
            routeGroup,
            arguments: GroupScreenArguments(id: group.id, name: group.name),
          ),
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GroupMark.forGroup(group, size: 40),
                      const Spacer(),
                      if (group.pinned)
                        Icon(
                          Icons.push_pin,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
