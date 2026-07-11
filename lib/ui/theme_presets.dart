import 'package:flutter/material.dart';

/// Hand-tuned theme presets that override the seed-color theming entirely.
///
/// "Fairy Forest" is a warm paper-cream light theme with forest green accents;
/// "Pitch Black" is a pure black theme with a vivid green accent.

ThemeData fairyForestTheme(PageTransitionsTheme? pageTransitions) {
  const paper = Color(0xFFF3EEE2);
  const paperCard = Color(0xFFECE5D5);
  const paperDeep = Color(0xFFE4DCC9);
  const forest = Color(0xFF2E6B4F);

  final scheme = ColorScheme.fromSeed(seedColor: forest, brightness: Brightness.light).copyWith(
    primary: forest,
    secondary: const Color(0xFF4E7D62),
    surface: paper,
    surfaceContainerLowest: paper,
    surfaceContainerLow: paperCard,
    surfaceContainer: paperCard,
    surfaceContainerHigh: paperDeep,
    surfaceContainerHighest: paperDeep,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    appBarTheme: const AppBarThemeData(backgroundColor: paper),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: paperCard),
    pageTransitionsTheme: pageTransitions,
  );
}

ThemeData pitchBlackTheme(PageTransitionsTheme? pageTransitions) {
  const green = Color(0xFF00C853);

  final scheme = ColorScheme.fromSeed(seedColor: green, brightness: Brightness.dark).copyWith(
    primary: green,
    onPrimary: Colors.black,
    secondary: const Color(0xFF69F0AE),
    surface: Colors.black,
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: const Color(0xFF0A0A0A),
    surfaceContainer: const Color(0xFF0F0F0F),
    surfaceContainerHigh: const Color(0xFF151515),
    surfaceContainerHighest: const Color(0xFF1B1B1B),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarThemeData(backgroundColor: Colors.black),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.black),
    pageTransitionsTheme: pageTransitions,
  );
}
