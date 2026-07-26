import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/constants.dart';
import 'package:quax/ui/x_look_theme.dart';

/// X Look is now the app's only design language, chosen on two axes the way X
/// does it: how dark the background is, and which accent sits on it. These pin
/// the resolution between the two settings and an actual ThemeData, and the
/// migration that carries an existing install across.
void main() {
  group('xLookTokensFor', () {
    test('each background resolves to its own palette', () {
      expect(xLookTokensFor(xLookBackgroundLight, xLookAccentBlue).background, XLookTokens.light.background);
      expect(xLookTokensFor(xLookBackgroundDim, xLookAccentBlue).background, XLookTokens.dim.background);
      expect(xLookTokensFor(xLookBackgroundLightsOut, xLookAccentBlue).background, XLookTokens.lightsOut.background);
    });

    test('the accent is applied without disturbing the background', () {
      final green = xLookTokensFor(xLookBackgroundLightsOut, 'green');

      expect(green.accent, xLookAccents['green']);
      expect(green.background, XLookTokens.lightsOut.background);
      expect(green.onBackground, XLookTokens.lightsOut.onBackground);
    });

    test('every accent is offered on every background', () {
      for (final background in xLookBackgrounds) {
        for (final accent in xLookAccents.keys) {
          expect(xLookTokensFor(background, accent).accent, xLookAccents[accent], reason: '$background/$accent');
        }
      }
    });

    test('an accent we no longer recognise falls back to blue rather than crashing', () {
      expect(xLookAccentColor('chartreuse'), xLookAccents[xLookAccentBlue]);
      expect(xLookTokensFor(xLookBackgroundDim, 'chartreuse').accent, xLookAccents[xLookAccentBlue]);
    });
  });

  group('the dark half', () {
    test('Dim darkens to Dim, everything else to Lights Out', () {
      expect(xLookDarkTokensFor(xLookBackgroundDim, xLookAccentBlue).background, XLookTokens.dim.background);
      expect(xLookDarkTokensFor(xLookBackgroundSystem, xLookAccentBlue).background, XLookTokens.lightsOut.background);
      expect(
          xLookDarkTokensFor(xLookBackgroundLightsOut, xLookAccentBlue).background, XLookTokens.lightsOut.background);
    });

    test('a light-mode reader on System is never dragged into a black UI', () {
      expect(xLookThemeModeFor(xLookBackgroundSystem), ThemeMode.system);
      expect(xLookTokensFor(xLookBackgroundLight, xLookAccentBlue).background, XLookTokens.light.background);
    });
  });

  group('xLookThemeModeFor', () {
    test('only System defers to the phone', () {
      expect(xLookThemeModeFor(xLookBackgroundSystem), ThemeMode.system);
      expect(xLookThemeModeFor(xLookBackgroundLight), ThemeMode.light);
      expect(xLookThemeModeFor(xLookBackgroundDim), ThemeMode.dark);
      expect(xLookThemeModeFor(xLookBackgroundLightsOut), ThemeMode.dark);
    });
  });

  group('migrating an existing install', () {
    test('the three X Look presets keep the look they had', () {
      expect(xLookBackgroundForPreset(themePresetXLookLight), xLookBackgroundLight);
      expect(xLookBackgroundForPreset(themePresetXLookDim), xLookBackgroundDim);
      expect(xLookBackgroundForPreset(themePresetXLookLightsOut), xLookBackgroundLightsOut);
    });

    test('the retired presets have no equivalent, so they follow the system', () {
      for (final preset in [themePresetNone, themePresetFairyForest, themePresetPitchBlack, null, 'something_else']) {
        expect(xLookBackgroundForPreset(preset), xLookBackgroundSystem, reason: '$preset');
      }
    });
  });

  group('the resulting ThemeData', () {
    test('carries the tokens, so widgets reading XLookTokens still find them', () {
      final theme = xLookThemeData(xLookTokensFor(xLookBackgroundLightsOut, 'green'), null);

      expect(theme.extension<XLookTokens>()?.accent, xLookAccents['green']);
      expect(theme.colorScheme.primary, xLookAccents['green']);
      expect(theme.scaffoldBackgroundColor, XLookTokens.lightsOut.background);
    });

    test('brightness follows the background, not the accent', () {
      expect(xLookThemeData(xLookTokensFor(xLookBackgroundLight, 'purple'), null).brightness, Brightness.light);
      expect(xLookThemeData(xLookTokensFor(xLookBackgroundDim, 'yellow'), null).brightness, Brightness.dark);
      expect(xLookThemeData(xLookTokensFor(xLookBackgroundLightsOut, 'pink'), null).brightness, Brightness.dark);
    });
  });
}
