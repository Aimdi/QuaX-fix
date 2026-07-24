import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:pref/pref.dart';

/// Deterministic seed color for groups without a chosen color. Stable for a
/// given name so tiles stay consistent across reloads.
Color hashedSeedColor(String key) {
  final hue = (key.codeUnits.fold<int>(0, (h, c) => h * 31 + c) % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.5, 0.5).toColor();
}

/// Contrast-safe tonal fill + on-fill pair from a seed, adapted to brightness.
({Color container, Color onContainer}) tonalPair(BuildContext context, Color seed) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Theme.of(context).brightness,
  );
  return (container: scheme.primaryContainer, onContainer: scheme.onPrimaryContainer);
}

/// 1–2 grapheme monogram; umlaut-safe via [Characters].
String monogram(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  final chars = trimmed.characters;
  final take = chars.length >= 2 ? 2 : 1;
  return chars.take(take).toString().toUpperCase();
}

/// True Black / Pitch Black / X lights-out: prefer neutral surface + color accent.
bool useAccentTileVariant(BuildContext context) {
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
    // PrefService absent (e.g. isolated widget tests) — tonal fill is fine.
  }
  return false;
}

Color groupSeedColor(SubscriptionGroup group) => group.color ?? hashedSeedColor(group.name);

/// Stored Material icon, or a monogram when the group still has the default RSS icon.
Widget groupGlyph(SubscriptionGroup group, {required Color color, double size = 28}) {
  if (group.icon == defaultGroupIcon) {
    return Text(
      monogram(group.name),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.7,
        height: 1,
      ),
    );
  }
  return Icon(group.iconData, size: size, color: color);
}
