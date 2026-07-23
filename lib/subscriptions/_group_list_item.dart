import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/user.dart';
import 'package:provider/provider.dart';

/// Deterministic fallback color for groups without a chosen color, hashed from
/// the group name so the same group always gets the same hue.
Color groupFallbackColor(String name) {
  final hue = (name.codeUnits.fold<int>(0, (h, c) => h * 31 + c) % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.45, 0.55).toColor();
}

/// One group as a dense list row: colored avatar with the group's icon (or a
/// monogram when none was chosen), name, member count and a preview cluster of
/// member avatars. The group color lives only on the small avatar, so the text
/// keeps the theme's contrast.
class GroupListItem extends StatelessWidget {
  final SubscriptionGroup group;
  final VoidCallback? onLongPress;

  // When set, the row is part of a manually-ordered list and shows a drag
  // handle bound to this index.
  final int? reorderIndex;

  const GroupListItem({super.key, required this.group, this.onLongPress, this.reorderIndex});

  Widget _buildTrailing(BuildContext context) {
    final l10n = L10n.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(group.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
              color: group.pinned ? Theme.of(context).colorScheme.primary : Theme.of(context).hintColor),
          tooltip: group.pinned ? l10n.unpin : l10n.pin,
          onPressed: () => context.read<GroupsModel>().toggleGroupPinned(group.id, !group.pinned),
        ),
        if (reorderIndex != null)
          ReorderableDragStartListener(
            index: reorderIndex!,
            child: Icon(Icons.drag_handle, color: Theme.of(context).hintColor),
          )
        else
          const Icon(Icons.chevron_right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = (group.color ?? groupFallbackColor(group.name)).harmonizeWith(theme.colorScheme.primary);
    final onFill =
        ThemeData.estimateBrightnessForColor(fill) == Brightness.dark ? Colors.white : Colors.black87;
    final hiddenMembers = group.numberOfMembers - group.memberAvatarUrls.length;

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: fill,
        child: group.icon == defaultGroupIcon
            ? Text(group.name.isEmpty ? '?' : group.name.characters.first.toUpperCase(),
                style: TextStyle(color: onFill, fontWeight: FontWeight.w700, fontSize: 16))
            : Icon(group.iconData, size: 20, color: onFill),
      ),
      title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(L10n.of(context).subscription_group_member_count(group.numberOfMembers),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (group.memberAvatarUrls.isNotEmpty) ...[
            const SizedBox(width: 8),
            ExcludeSemantics(child: _AvatarCluster(urls: group.memberAvatarUrls)),
            if (hiddenMembers > 0) ...[
              const SizedBox(width: 4),
              Text('+$hiddenMembers', style: theme.textTheme.bodySmall),
            ],
          ],
        ],
      ),
      trailing: _buildTrailing(context),
      onTap: () => Navigator.pushNamed(context, routeGroup,
          arguments: GroupScreenArguments(id: group.id, name: group.name)),
      onLongPress: onLongPress,
    );
  }
}

class _AvatarCluster extends StatelessWidget {
  static const double _size = 20;
  static const double _step = 13;
  static const double _ring = 1.5;

  final List<String> urls;

  const _AvatarCluster({required this.urls});

  @override
  Widget build(BuildContext context) {
    final ringColor = Theme.of(context).colorScheme.surface;
    final diameter = _size + 2 * _ring;

    return SizedBox(
      height: diameter,
      width: (urls.length - 1) * _step + diameter,
      child: Stack(
        children: [
          for (final (i, url) in urls.indexed)
            Positioned(
              left: i * _step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: _ring),
                ),
                child: UserAvatar(uri: url, size: _size),
              ),
            ),
        ],
      ),
    );
  }
}
