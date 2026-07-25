import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/tweet_footer.dart';

/// An icon-only button with no accessible name is announced as an unnamed
/// "button". The footer has several on every post, so the omission repeated all
/// the way down a timeline.
///
/// Flutter exposes an IconButton's tooltip through the semantics node's
/// `tooltip` property rather than its `label` — screen readers announce it
/// either way, so that is what these assert on.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => child)),
    ),
  );

  testWidgets('a labelled footer button carries that name into the semantics tree', (tester) async {
    final handle = tester.ensureSemantics();

    await pump(
      tester,
      Builder(builder: (context) => tweetFooterIconButton(context, Icons.share, null, null, () {}, 'Share post')),
    );

    expect(tester.getSemantics(find.byType(IconButton)).tooltip, 'Share post');
    handle.dispose();
  });

  testWidgets('saving and unsaving are told apart by name, not only by icon', (tester) async {
    final handle = tester.ensureSemantics();

    await pump(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            tweetFooterIconButton(context, Icons.bookmark_border, null, 0, () {}, 'Save post'),
            tweetFooterIconButton(context, Icons.bookmark, null, 1, () {}, 'Remove from saved'),
          ],
        ),
      ),
    );

    final names = tester.widgetList<IconButton>(find.byType(IconButton)).map((button) => button.tooltip).toList();

    expect(names, ['Save post', 'Remove from saved']);
    handle.dispose();
  });

  testWidgets('a button with no name still builds, so callers keep the choice', (tester) async {
    await pump(tester, Builder(builder: (context) => tweetFooterIconButton(context, Icons.bar_chart)));

    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    expect(tester.widget<IconButton>(find.byType(IconButton)).tooltip, isNull);
  });
}
