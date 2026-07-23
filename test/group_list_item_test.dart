import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/_group_list_item.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.delegate.supportedLocales,
      home: Material(child: child),
    );

SubscriptionGroup _group({String name = 'Anime', String? icon, int members = 15}) => SubscriptionGroup(
      id: 'g1',
      name: name,
      icon: icon ?? defaultGroupIcon,
      color: null,
      numberOfMembers: members,
      createdAt: DateTime.utc(2024),
    );

void main() {
  test('groupFallbackColor is deterministic per name', () {
    expect(groupFallbackColor('Anime'), groupFallbackColor('Anime'));
    expect(groupFallbackColor('Anime') == groupFallbackColor('Art'), isFalse);
  });

  testWidgets('shows a monogram for the default icon and the localized member count', (tester) async {
    await tester.pumpWidget(_wrap(GroupListItem(group: _group())));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('15 subscriptions'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('singular member count uses the singular form', (tester) async {
    await tester.pumpWidget(_wrap(GroupListItem(group: _group(members: 1))));
    await tester.pumpAndSettle();

    expect(find.text('1 subscription'), findsOneWidget);
  });

  testWidgets('shows the chosen icon instead of a monogram', (tester) async {
    const icon = '{"pack":"material","key":"star"}';
    await tester.pumpWidget(_wrap(GroupListItem(group: _group(icon: icon))));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsNothing);
  });
}
