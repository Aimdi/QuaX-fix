import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:quax/constants.dart';

/// X design-language tokens. Chirp is proprietary — we use Inter instead.
@immutable
class XLookTokens extends ThemeExtension<XLookTokens> {
  final Color accent;
  final Color background;
  final Color onBackground;
  final Color secondary;
  final Color divider;
  final Color card;
  final Color border;
  final double mediaRadius;
  final double avatarSize;
  final double spacing;

  const XLookTokens({
    required this.accent,
    required this.background,
    required this.onBackground,
    required this.secondary,
    required this.divider,
    required this.card,
    required this.border,
    this.mediaRadius = 16,
    this.avatarSize = 40,
    this.spacing = 4,
  });

  static const accentBlue = Color(0xFF1D9BF0);

  static const light = XLookTokens(
    accent: accentBlue,
    background: Color(0xFFFFFFFF),
    onBackground: Color(0xFF0F1419),
    secondary: Color(0xFF536471),
    divider: Color(0xFFEFF3F4),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFEFF3F4),
  );

  static const dim = XLookTokens(
    accent: accentBlue,
    background: Color(0xFF15202B),
    onBackground: Color(0xFFF7F9F9),
    secondary: Color(0xFF8899A4),
    divider: Color(0xFF38444D),
    card: Color(0xFF192734),
    border: Color(0xFF38444D),
  );

  static const lightsOut = XLookTokens(
    accent: accentBlue,
    background: Color(0xFF000000),
    onBackground: Color(0xFFE7E9EA),
    secondary: Color(0xFF71767B),
    divider: Color(0xFF2F3336),
    card: Color(0xFF000000),
    border: Color(0xFF2F3336),
  );

  static XLookTokens? maybeOf(BuildContext context) => Theme.of(context).extension<XLookTokens>();

  static XLookTokens of(BuildContext context) {
    final tokens = maybeOf(context);
    assert(tokens != null, 'XLookTokens missing from Theme');
    return tokens!;
  }

  @override
  XLookTokens copyWith({
    Color? accent,
    Color? background,
    Color? onBackground,
    Color? secondary,
    Color? divider,
    Color? card,
    Color? border,
    double? mediaRadius,
    double? avatarSize,
    double? spacing,
  }) {
    return XLookTokens(
      accent: accent ?? this.accent,
      background: background ?? this.background,
      onBackground: onBackground ?? this.onBackground,
      secondary: secondary ?? this.secondary,
      divider: divider ?? this.divider,
      card: card ?? this.card,
      border: border ?? this.border,
      mediaRadius: mediaRadius ?? this.mediaRadius,
      avatarSize: avatarSize ?? this.avatarSize,
      spacing: spacing ?? this.spacing,
    );
  }

  @override
  XLookTokens lerp(ThemeExtension<XLookTokens>? other, double t) {
    if (other is! XLookTokens) return this;
    return XLookTokens(
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      mediaRadius: lerpDouble(mediaRadius, other.mediaRadius, t)!,
      avatarSize: lerpDouble(avatarSize, other.avatarSize, t)!,
      spacing: lerpDouble(spacing, other.spacing, t)!,
    );
  }
}

TextTheme _xLookTextTheme(Brightness brightness, Color onBg, Color secondary) {
  final base = brightness == Brightness.light ? Typography.material2021().black : Typography.material2021().white;
  return base
      .apply(fontFamily: 'Inter', bodyColor: onBg, displayColor: onBg)
      .copyWith(
        bodyLarge: base.bodyLarge?.copyWith(fontFamily: 'Inter', fontSize: 15, color: onBg, height: 1.35),
        bodyMedium: base.bodyMedium?.copyWith(fontFamily: 'Inter', fontSize: 15, color: onBg, height: 1.35),
        bodySmall: base.bodySmall?.copyWith(fontFamily: 'Inter', fontSize: 13, color: secondary),
        titleLarge: base.titleLarge?.copyWith(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: onBg),
        titleMedium: base.titleMedium?.copyWith(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: onBg),
        titleSmall: base.titleSmall?.copyWith(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: onBg),
        labelLarge: base.labelLarge?.copyWith(fontFamily: 'Inter', fontWeight: FontWeight.w700, color: onBg),
      );
}

ThemeData xLookThemeData(XLookTokens tokens, PageTransitionsTheme? pageTransitions) {
  final isLight = tokens.background.computeLuminance() > 0.5;
  final brightness = isLight ? Brightness.light : Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: tokens.accent,
    onPrimary: Colors.white,
    secondary: tokens.accent,
    onSecondary: Colors.white,
    error: const Color(0xFFF4212E),
    onError: Colors.white,
    surface: tokens.card,
    onSurface: tokens.onBackground,
    onSurfaceVariant: tokens.secondary,
    outline: tokens.border,
    outlineVariant: tokens.divider,
    surfaceContainerLowest: tokens.background,
    surfaceContainerLow: tokens.card,
    surfaceContainer: tokens.card,
    surfaceContainerHigh: tokens.card,
    surfaceContainerHighest: tokens.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.background,
    cardColor: tokens.card,
    dividerColor: tokens.divider,
    fontFamily: 'Inter',
    textTheme: _xLookTextTheme(brightness, tokens.onBackground, tokens.secondary),
    appBarTheme: AppBarThemeData(
      backgroundColor: tokens.background,
      foregroundColor: tokens.onBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: tokens.onBackground,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.background,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 56,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? tokens.accent : tokens.secondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? tokens.accent : tokens.secondary, size: 24);
      }),
    ),
    // Material 3 draws snackbars on inverseSurface, which in a dark app means a
    // light slab with dark text — the one surface that ignored the theme.
    snackBarTheme: SnackBarThemeData(
      // Lights Out makes card and background both pure black, so a snackbar
      // drawn on either would be invisible against the screen behind it.
      backgroundColor: tokens.card == tokens.background
          ? Color.alphaBlend(tokens.onBackground.withValues(alpha: 0.10), tokens.background)
          : tokens.card,
      contentTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 15, color: tokens.onBackground),
      actionTextColor: tokens.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: tokens.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.onBackground,
        side: BorderSide(color: tokens.border),
        shape: const StadiumBorder(),
      ),
    ),
    pageTransitionsTheme: pageTransitions ??
        const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
    extensions: [tokens],
  );
}

ThemeData xLookLightTheme(PageTransitionsTheme? pageTransitions) =>
    xLookThemeData(XLookTokens.light, pageTransitions);

ThemeData xLookDimTheme(PageTransitionsTheme? pageTransitions) =>
    xLookThemeData(XLookTokens.dim, pageTransitions);

ThemeData xLookLightsOutTheme(PageTransitionsTheme? pageTransitions) =>
    xLookThemeData(XLookTokens.lightsOut, pageTransitions);

bool isXLookPreset(String preset) =>
    preset == 'x_look_light' || preset == 'x_look_dim' || preset == 'x_look_lights_out';

/// The accent for [accent], falling back to X's blue for a value we no longer
/// recognise rather than leaving the app without a usable colour.
Color xLookAccentColor(String accent) => xLookAccents[accent] ?? xLookAccents[xLookAccentBlue]!;

/// Tokens for one background, tinted with the chosen accent.
///
/// [background] here is a concrete background — pass [xLookBackgroundLight] for
/// the light theme; use [xLookDarkTokensFor] to resolve the dark one.
XLookTokens xLookTokensFor(String background, String accent) {
  final base = switch (background) {
    xLookBackgroundLight => XLookTokens.light,
    xLookBackgroundDim => XLookTokens.dim,
    _ => XLookTokens.lightsOut,
  };

  return base.copyWith(accent: xLookAccentColor(accent));
}

/// The dark half of the theme. "System" darkens to Lights Out, which is true
/// black and the cheapest on an OLED panel; Dim is a deliberate choice.
XLookTokens xLookDarkTokensFor(String background, String accent) => xLookTokensFor(
      background == xLookBackgroundDim ? xLookBackgroundDim : xLookBackgroundLightsOut,
      accent,
    );

/// Only "System" defers to the phone; every other background names a brightness.
ThemeMode xLookThemeModeFor(String background) => switch (background) {
      xLookBackgroundSystem => ThemeMode.system,
      xLookBackgroundLight => ThemeMode.light,
      _ => ThemeMode.dark,
    };

/// Maps a stored theme preset onto the background that replaced it, so an
/// existing install keeps the look it had. The three retired presets (Standard,
/// Fairy Forest, Pitch Black) have no X Look equivalent and fall to System.
String xLookBackgroundForPreset(String? preset) => switch (preset) {
      themePresetXLookLight => xLookBackgroundLight,
      themePresetXLookDim => xLookBackgroundDim,
      themePresetXLookLightsOut => xLookBackgroundLightsOut,
      _ => xLookBackgroundSystem,
    };
