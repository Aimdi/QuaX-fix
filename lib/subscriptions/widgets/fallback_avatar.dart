import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Saturated base palette for member avatars that have no picture. Never grey —
/// grey reads as "broken", and the whole point is that a missing avatar should
/// look deliberate.
const _basePalette = <Color>[
  Color(0xFF1D9BF0),
  Color(0xFFF91880),
  Color(0xFF7856FF),
  Color(0xFFFF7A00),
  Color(0xFF00BA7C),
  Color(0xFFFFD400),
  Color(0xFFE0245E),
  Color(0xFF17BF63),
  Color(0xFF794BC4),
  Color(0xFFFF6F00),
  Color(0xFF1B95E0),
  Color(0xFFF45D22),
  Color(0xFF2EC7C2),
  Color(0xFFE0457B),
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
];

// Harmonising 16 colours runs HCT maths, far too costly to repeat per avatar
// per frame, so the derived palette is memoised per accent.
Color? _cachedAccent;
List<Color>? _cachedPalette;

/// The base palette rotated towards [accent], so the cream and green themes get
/// a palette that belongs to them instead of a foreign rainbow.
List<Color> fallbackAvatarPalette(Color accent) {
  if (_cachedAccent != accent || _cachedPalette == null) {
    _cachedAccent = accent;
    _cachedPalette = _basePalette.map((c) => c.harmonizeWith(accent)).toList(growable: false);
  }
  return _cachedPalette!;
}

/// Stable per-identity colour index. Seeded by the subscription's id rather
/// than its display name, so renames and duplicate names stay stable/distinct.
int fallbackAvatarIndex(String seed, int paletteLength) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = unit + ((hash << 5) - hash);
  }
  return (hash % paletteLength + paletteLength) % paletteLength;
}

final _alphanumeric = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// First letter or digit of [name], falling back to [seed] and finally '#'.
String fallbackAvatarInitial(String name, String seed) {
  final match = _alphanumeric.firstMatch(name) ?? _alphanumeric.firstMatch(seed);
  return (match?.group(0) ?? '#').toUpperCase();
}

/// A member avatar with no usable picture: a coloured circle with one initial,
/// identical in size and shape to a loaded avatar so a partially-loaded mosaic
/// still looks intentional.
class FallbackAvatar extends StatelessWidget {
  final String seed;
  final String displayName;
  final double size;
  final Color accent;

  const FallbackAvatar({
    super.key,
    required this.seed,
    required this.displayName,
    required this.size,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = fallbackAvatarPalette(accent);
    final background = palette[fallbackAvatarIndex(seed, palette.length)];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        fallbackAvatarInitial(displayName, seed),
        // The initial must not rescale with the user's text-size setting, or it
        // would overflow its circle.
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size * 0.46,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}
