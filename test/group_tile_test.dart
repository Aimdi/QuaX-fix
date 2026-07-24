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

SubscriptionGroup _group({String name = 'Anime', String? icon, int members = 15, bool pinned = false}) =>
    SubscriptionGroup(
      id: 'g1',
      name: name,
      icon: icon ?? defaultGroupIcon,
      color: null,
      numberOfMembers: members,
      createdAt: DateTime.utc(2024),
      pinned: pinned,
    );

void main() {
  test('hashedSeedColor is deterministic per name', () {
    expect(hashedSeedColor('Anime'), hashedSeedColor('Anime'));
    expect(hashedSeedColor('Anime') == hashedSeedColor('Art'), isFalse);
  });

  test('monogram handles umlauts, compounds, and empty names', () {
    expect(monogram('Über'), 'ÜB');
    expect(monogram('Anime'), 'AN');
    expect(monogram('A'), 'A');
    expect(monogram('  '), '?');
    expect(monogram(''), '?');
  });

  testWidgets('tile shows monogram, name, and localized member count', (tester) async {
    await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group())));
    await tester.pumpAndSettle();

    expect(find.text('AN'), findsOneWidget);
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('15 subscriptions'), findsOneWidget);
  });

  testWidgets('singular member count uses the singular form', (tester) async {
    await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group(members: 1))));
    await tester.pumpAndSettle();

    expect(find.text('1 subscription'), findsOneWidget);
  });

  testWidgets('shows the chosen icon instead of a monogram', (tester) async {
    const icon = '{"pack":"material","key":"star"}';
    await tester.pumpWidget(_wrap(SubscriptionGroupTile(group: _group(icon: icon))));
    await tester.pumpAndSettle();

    expect(find.text('AN'), findsNothing);
    expect(find.byIcon(Icons.star), findsOneWidget);
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
}
