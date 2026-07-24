import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
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
///
/// One letter + color disambiguates colliding names (`Art (1)` / `Art NSFW` →
/// both `A`). Never returns a two-letter monogram.
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

/// 40dp tonal chip: Phase 1 always shows [groupInitial]. Emoji / stored icon /
/// generative fallbacks arrive with `mark_style` in Phase 2.
class GroupMark extends StatelessWidget {
  final String name;
  final Color seed;
  final double size;

  const GroupMark({
    super.key,
    required this.name,
    required this.seed,
    this.size = 40,
  });

  factory GroupMark.forGroup(SubscriptionGroup group, {Key? key, double size = 40}) {
    return GroupMark(
      key: key,
      name: group.name,
      seed: groupSeedColor(group),
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pair = tonalPair(context, seed);
    final initial = groupInitial(name);
    final fontSize = size * 0.5;

    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: pair.container,
          borderRadius: BorderRadius.circular(size * 0.3),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: pair.onContainer,
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
