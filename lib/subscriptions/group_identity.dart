import 'package:flutter/material.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/group_mark_style.dart';

/// Deterministic fallback color for groups without a chosen color, hashed from
/// the group name so the same group always gets the same hue.
Color groupFallbackColor(String name) {
  final hue = (name.codeUnits.fold<int>(0, (h, c) => h * 31 + c) % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.45, 0.55).toColor();
}

Color groupSeedColor(SubscriptionGroup group) => group.color ?? groupFallbackColor(group.name);

/// Contrast-safe tonal fill + on-fill pair from a seed, adapted to brightness.
({Color container, Color onContainer}) tonalPair(BuildContext context, Color seed) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Theme.of(context).brightness,
  );
  return (container: scheme.primaryContainer, onContainer: scheme.onPrimaryContainer);
}

final RegExp _letterGrapheme = RegExp(r'\p{L}', unicode: true);

/// Single dominant initial: first letter grapheme, else first grapheme, else `?`.
///
/// One letter plus colour disambiguates colliding names (`Art (1)` /
/// `Art NSFW` both give `A`) without the weight of a two-letter monogram.
String groupInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  for (final grapheme in trimmed.characters) {
    if (_letterGrapheme.hasMatch(grapheme)) {
      return grapheme.toUpperCase();
    }
  }
  return trimmed.characters.first.toUpperCase();
}

bool _hasEmoji(String? emoji) => emoji != null && emoji.trim().isNotEmpty;

bool _hasCustomIcon(String icon) =>
    icon.isNotEmpty && icon != defaultGroupIcon && icon != 'rss' && icon != 'rss_feed';

/// Which mark content a chip should show for [markStyle] plus stored fields.
enum GroupMarkKind { emoji, initial, symbol }

GroupMarkKind resolveGroupMarkKind({
  required int markStyle,
  required String? emoji,
  required String icon,
}) {
  switch (GroupMarkStyle.coerce(markStyle)) {
    case GroupMarkStyle.emoji:
      return _hasEmoji(emoji) ? GroupMarkKind.emoji : GroupMarkKind.initial;
    case GroupMarkStyle.symbol:
      return _hasCustomIcon(icon) ? GroupMarkKind.symbol : GroupMarkKind.initial;
    case GroupMarkStyle.generated:
      return GroupMarkKind.initial;
    case GroupMarkStyle.auto:
    default:
      return _hasEmoji(emoji) ? GroupMarkKind.emoji : GroupMarkKind.initial;
  }
}

/// True when the user picked an explicit mark for this group, so it should win
/// over the member-faced mosaic on the board.
bool hasExplicitGroupMark(SubscriptionGroup group) {
  final style = GroupMarkStyle.coerce(group.markStyle);
  if (style == GroupMarkStyle.emoji || style == GroupMarkStyle.symbol) {
    return resolveGroupMarkKind(markStyle: style, emoji: group.emoji, icon: group.icon) !=
        GroupMarkKind.initial;
  }
  return _hasEmoji(group.emoji);
}

/// Tonal chip with a single resolver path for emoji / initial / symbol.
class GroupMark extends StatelessWidget {
  final String name;
  final Color seed;
  final String? emoji;
  final String icon;
  final int markStyle;
  final double size;

  const GroupMark({
    super.key,
    required this.name,
    required this.seed,
    this.emoji,
    this.icon = '',
    this.markStyle = GroupMarkStyle.auto,
    this.size = 40,
  });

  factory GroupMark.forGroup(SubscriptionGroup group, {Key? key, double size = 40}) {
    return GroupMark(
      key: key,
      name: group.name,
      seed: groupSeedColor(group),
      emoji: group.emoji,
      icon: group.icon,
      markStyle: group.markStyle,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pair = tonalPair(context, seed);
    final kind = resolveGroupMarkKind(markStyle: markStyle, emoji: emoji, icon: icon);
    final child = switch (kind) {
      GroupMarkKind.emoji => Text(
          emoji!.trim().characters.first,
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: size * 0.55, height: 1),
        ),
      GroupMarkKind.symbol => Icon(
          deserializeIconData(icon),
          size: size * 0.55,
          color: pair.onContainer,
        ),
      GroupMarkKind.initial => Text(
          groupInitial(name),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: pair.onContainer,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.5,
            height: 1,
            letterSpacing: 0,
          ),
        ),
    };

    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: pair.container,
          borderRadius: BorderRadius.circular(size * 0.3),
          child: Center(child: child),
        ),
      ),
    );
  }
}
