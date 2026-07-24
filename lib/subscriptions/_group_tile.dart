import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/subscriptions/group_identity.dart';

/// Compact Groups-grid tile: image-free tonal (or accent) chrome with glyph,
/// name, member count, and optional pin mark.
class SubscriptionGroupTile extends StatelessWidget {
  final SubscriptionGroup group;
  final VoidCallback? onLongPress;

  const SubscriptionGroupTile({super.key, required this.group, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final seed = groupSeedColor(group);
    final accent = useAccentTileVariant(context);
    final pair = tonalPair(context, seed);

    final Color fill;
    final Color onFill;
    final Color? accentBar;
    if (accent) {
      fill = theme.colorScheme.surfaceContainerHigh;
      onFill = theme.colorScheme.onSurface;
      accentBar = seed;
    } else {
      fill = pair.container;
      onFill = pair.onContainer;
      accentBar = null;
    }

    final countLabel = l10n.subscription_group_member_count(group.numberOfMembers);
    final semanticsLabel = '${group.name}, $countLabel';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            routeGroup,
            arguments: GroupScreenArguments(id: group.id, name: group.name),
          ),
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Stack(
              children: [
                if (accentBar != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: ColoredBox(color: accentBar),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(accentBar != null ? 12 : 10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          groupGlyph(group, color: onFill, size: 28),
                          const Spacer(),
                          if (group.pinned)
                            Icon(Icons.push_pin, size: 16, color: onFill.withValues(alpha: 0.85)),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        group.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: onFill,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        countLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onFill.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
