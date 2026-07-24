import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/_group_tile.dart';
import 'package:quax/subscriptions/group_identity.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.delegate.supportedLocales,
      home: Material(child: SizedBox(width: 120, height: 90, child: child)),
    );

SubscriptionGroup _group({
  String name = 'Anime',
  String? icon,
  Color? color,
  int members = 15,
  bool pinned = false,
}) =>
    SubscriptionGroup(
      id: 'g1',
      name: name,
      icon: icon ?? defaultGroupIcon,
      color: color,
      numberOfMembers: members,
      createdAt: DateTime.utc(2024),
      pinned: pinned,
    );

void main() {
  test('hashedSeedColor is deterministic per name', () {
    expect(hashedSeedColor('Anime'), hashedSeedColor('Anime'));
    expect(hashedSeedColor('Anime') == hashedSeedColor('Art'), isFalse);
  });

  test('groupInitial is a single letter and skips leading non-letters', () {
    expect(groupInitial('Art (1)'), 'A');
    expect(groupInitial('Art (2)'), 'A');
    expect(groupInitial('Art NSFW'), 'A');
    expect(groupInitial('German & EU'), 'G');
    expect(groupInitial('Über'), 'Ü');
    expect(groupInitial('Anime'), 'A');
    expect(groupInitial('  '), '?');
    expect(groupInitial(''), '?');
    expect(groupInitial('42'), '4');
  });

  testWidgets('tintedSurface differs from raw seed and from base surface', (tester) async {
    final seed = const Color(0xFFE53935);
    late Color tinted;
    late Color base;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
      ),
      home: Builder(builder: (context) {
        base = Theme.of(context).colorScheme.surfaceContainerHigh;
        tinted = tintedSurface(context, seed);
        return const SizedBox.shrink();
      }),
    ));
    expect(tinted, isNot(equals(seed)));
    expect(tinted, isNot(equals(base)));
  });

  testWidgets('tile shows single initial, name, and localized member count', (tester) async {
    await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group())));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('AN'), findsNothing);
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('15 subscriptions'), findsOneWidget);
  });

  testWidgets('singular member count uses the singular form', (tester) async {
    await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group(members: 1))));
    await tester.pumpAndSettle();

    expect(find.text('1 subscription'), findsOneWidget);
  });

  testWidgets('custom icon is not shown on the tile in Phase 1', (tester) async {
    const icon = '{"pack":"material","key":"star"}';
    await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group(icon: icon))));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('colliding Art* names all resolve to A', (tester) async {
    for (final name in ['Art (1)', 'Art (2)', 'Art NSFW']) {
      await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group(name: name))));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('AR'), findsNothing);
    }
  });

  testWidgets('German & EU initial is G not a euro glyph', (tester) async {
    await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group(name: 'German & EU'))));
    await tester.pumpAndSettle();

    expect(find.text('G'), findsOneWidget);
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('pinned group shows a pin mark', (tester) async {
    await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group(pinned: true))));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });

  testWidgets('long German name does not overflow at large text scale', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _wrap(SubscriptionGroupTile(group: _group(name: 'Nachrichtenüberblick'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Nachrichten'), findsOneWidget);
  });

  testWidgets('GroupMark is excluded from semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group())));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.byType(SubscriptionGroupTile));
    expect(semantics.label, contains('Anime'));
    expect(semantics.label, isNot(equals('A')));
    handle.dispose();
  });
}
