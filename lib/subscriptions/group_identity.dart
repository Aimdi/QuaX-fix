import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/group_mark_style.dart';
import 'package:pref/pref.dart';

/// Deterministic seed color for groups without a chosen color. Stable for a
/// given name so tiles stay consistent across reloads.
Color hashedSeedColor(String key) {
  final hue = (key.codeUnits.fold<int>(0, (h, c) => h * 31 + c) % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.5, 0.5).toColor();
}

Color groupSeedColor(SubscriptionGroup group) => group.color ?? hashedSeedColor(group.name);

/// Per-group tonal scheme (HCT-tuned container / onContainer pairs).
ColorScheme groupScheme(BuildContext context, Color seed) {
  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Theme.of(context).brightness,
  );
}

/// Contrast-safe tonal fill + on-fill pair from a seed, adapted to brightness.
({Color container, Color onContainer}) tonalPair(BuildContext context, Color seed) {
  final scheme = groupScheme(context, seed);
  return (container: scheme.primaryContainer, onContainer: scheme.onPrimaryContainer);
}

/// Cell fill: neutral surface softly tinted toward the group seed.
Color tintedSurface(BuildContext context, Color seed) {
  final base = Theme.of(context).colorScheme.surfaceContainerHigh;
  return Color.alphaBlend(seed.withValues(alpha: 0.12), base);
}

/// True Black / Pitch Black / X lights-out — hairline outline so tinted cells
/// separate from pure black.
bool useGroupMarkOutline(BuildContext context) {
  try {
    final prefs = PrefService.of(context, listen: false);
    final preset = prefs.get(optionThemePreset) as String? ?? themePresetNone;
    if (preset == themePresetPitchBlack || preset == themePresetXLookLightsOut) {
      return true;
    }
    if (prefs.get(optionThemeTrueBlack) == true && Theme.of(context).brightness == Brightness.dark) {
      return true;
    }
  } catch (_) {
    // PrefService absent (e.g. isolated widget tests).
  }
  return false;
}

@Deprecated('Use useGroupMarkOutline — accent-bar chrome retired in Iteration 3')
bool useAccentTileVariant(BuildContext context) => useGroupMarkOutline(context);

final RegExp _letterGrapheme = RegExp(r'\p{L}', unicode: true);

/// Single dominant initial: first letter grapheme, else first grapheme, else `?`.
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

@Deprecated('Use groupInitial — two-letter monograms collide and overpower chips')
String monogram(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  final chars = trimmed.characters;
  final take = chars.length >= 2 ? 2 : 1;
  return chars.take(take).toString().toUpperCase();
}

bool _hasEmoji(String? emoji) => emoji != null && emoji.trim().isNotEmpty;

bool _hasCustomIcon(String icon) =>
    icon.isNotEmpty && icon != defaultGroupIcon && icon != 'rss' && icon != 'rss_feed';

/// Which mark content the chip should show for [markStyle] + stored fields.
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
      if (_hasEmoji(emoji)) {
        return GroupMarkKind.emoji;
      }
      return GroupMarkKind.initial;
  }
}

/// 40dp tonal chip with a single resolver path for emoji / initial / symbol.
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
          style: TextStyle(fontSize: size * 0.55, height: 1),
        ),
      GroupMarkKind.symbol => Icon(
          deserializeIconData(icon),
          size: size * 0.55,
          color: pair.onContainer,
        ),
      GroupMarkKind.initial => Text(
          groupInitial(name),
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
