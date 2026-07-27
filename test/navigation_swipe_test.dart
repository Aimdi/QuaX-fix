import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/home_screen.dart';

NavigationPage _page(String id, IconData icon) =>
    NavigationPage(id, (_) => id, Icon(icon), Icon(icon));

Widget _scaffold({int pages = 4, bool disableAnimations = false}) {
  final prefs = PrefServiceCache(cache: {
    optionShowNavigationLabels: false,
    optionDisableAnimations: disableAnimations,
  });

  return PrefService(
    service: prefs,
    child: MaterialApp(
      // The scaffold's drawer reads L10n, so the delegates have to be present.
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.delegate.supportedLocales,
      home: ScaffoldWithBottomNavigation(
        pages: [
          for (var i = 0; i < pages; i++) _page('page$i', Icons.circle),
        ],
        prefs: prefs,
        initialPage: 0,
        builder: (_, _) => [
          for (var i = 0; i < pages; i++) Center(child: Text('body$i')),
        ],
      ),
    ),
  );
}

Future<void> _swipeBar(WidgetTester tester, Offset offset) async {
  // The bar sits at the bottom of the scaffold; drag across it.
  final bar = find.byType(NavigationBar);
  await tester.fling(bar, offset, 600);
  await tester.pumpAndSettle();
}

/// Flings across the strip the app bar occupies, without touching the page.
Future<void> _swipeTop(WidgetTester tester, Offset offset) async {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  await tester.flingFrom(Offset(width / 2, kToolbarHeight / 2), offset, 600);
  await tester.pumpAndSettle();
}

void main() {
  group('pageAfterNavigationSwipe', () {
    test('a leftward swipe advances, a rightward one goes back', () {
      expect(pageAfterNavigationSwipe(current: 1, pageCount: 4, velocity: -800), 2);
      expect(pageAfterNavigationSwipe(current: 1, pageCount: 4, velocity: 800), 0);
    });

    test('the ends clamp rather than wrapping around', () {
      expect(pageAfterNavigationSwipe(current: 0, pageCount: 4, velocity: 800), 0);
      expect(pageAfterNavigationSwipe(current: 3, pageCount: 4, velocity: -800), 3);
    });

    test('a mis-tap, going nowhere at no speed, cannot change tab', () {
      expect(pageAfterNavigationSwipe(current: 1, pageCount: 4, velocity: -50), 1);
      expect(pageAfterNavigationSwipe(current: 1, pageCount: 4, velocity: 0), 1);
      expect(pageAfterNavigationSwipe(current: 1, pageCount: 4, velocity: -50, distance: -4), 1);
    });

    // The bar used to be gated on speed alone, so a deliberate drag — and any
    // drag paused before the finger lifted, which ends at no speed at all —
    // did nothing however far it went.
    test('a slow but long drag counts, even at no speed', () {
      expect(pageAfterNavigationSwipe(current: 1, pageCount: 4, velocity: 0, distance: -120), 2);
      expect(pageAfterNavigationSwipe(current: 1, pageCount: 4, velocity: 0, distance: 120), 0);
    });

    test('a long drag still clamps at the ends', () {
      expect(pageAfterNavigationSwipe(current: 0, pageCount: 4, velocity: 0, distance: 120), 0);
      expect(pageAfterNavigationSwipe(current: 3, pageCount: 4, velocity: 0, distance: -120), 3);
    });

    test('a flick decides the direction when it disagrees with where the finger stopped', () {
      // Dragged back to the right, then flicked left: the flick is the intent.
      expect(pageAfterNavigationSwipe(current: 1, pageCount: 4, velocity: -800, distance: 60), 2);
    });

    test('a single tab has nowhere to go', () {
      expect(pageAfterNavigationSwipe(current: 0, pageCount: 1, velocity: -800), 0);
      expect(pageAfterNavigationSwipe(current: 0, pageCount: 1, velocity: 0, distance: -400), 0);
    });
  });

  group('swiping the navigation bar', () {
    testWidgets('moves to the next tab and back', (tester) async {
      await tester.pumpWidget(_scaffold());
      await tester.pumpAndSettle();
      expect(find.text('body0'), findsOneWidget);

      await _swipeBar(tester, const Offset(-300, 0));
      expect(find.text('body1'), findsOneWidget);

      await _swipeBar(tester, const Offset(300, 0));
      expect(find.text('body0'), findsOneWidget);
    });

    testWidgets('does nothing at the first tab', (tester) async {
      await tester.pumpWidget(_scaffold());
      await tester.pumpAndSettle();

      await _swipeBar(tester, const Offset(300, 0));

      expect(find.text('body0'), findsOneWidget);
    });

    testWidgets('still switches when animations are turned off', (tester) async {
      await tester.pumpWidget(_scaffold(disableAnimations: true));
      await tester.pumpAndSettle();

      await _swipeBar(tester, const Offset(-300, 0));

      expect(find.text('body1'), findsOneWidget);
    });

    testWidgets('tapping a destination still works', (tester) async {
      await tester.pumpWidget(_scaffold());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.circle).last);
      await tester.pumpAndSettle();

      expect(find.text('body3'), findsOneWidget);
    });
  });

  // Every tab draws its own app bar inside a NestedScrollView, which took the
  // drag rather than letting it reach the pager — so the top of the screen, the
  // place a thumb already is, was the one place swiping did nothing.
  group('swiping the top of the screen', () {
    testWidgets('moves to the next tab and back', (tester) async {
      await tester.pumpWidget(_scaffold());
      await tester.pumpAndSettle();
      expect(find.text('body0'), findsOneWidget);

      await _swipeTop(tester, const Offset(-300, 0));
      expect(find.text('body1'), findsOneWidget);

      await _swipeTop(tester, const Offset(300, 0));
      expect(find.text('body0'), findsOneWidget);
    });

    testWidgets('the ends stay put', (tester) async {
      await tester.pumpWidget(_scaffold());
      await tester.pumpAndSettle();

      await _swipeTop(tester, const Offset(300, 0));

      expect(find.text('body0'), findsOneWidget);
    });

    // A single-tab scaffold is not a case that can be built: NavigationBar
    // requires at least two destinations. pageAfterNavigationSwipe covers the
    // rule directly above.

    testWidgets('a tap on the bar under the strip still lands', (tester) async {
      await tester.pumpWidget(_scaffold());
      await tester.pumpAndSettle();

      // The strip is translucent, so what is under it keeps taking taps.
      await tester.tap(find.byIcon(Icons.circle).last);
      await tester.pumpAndSettle();

      expect(find.text('body3'), findsOneWidget);
    });
  });
}
