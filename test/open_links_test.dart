import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/utils/urls.dart';

/// Records the launch requests `openUri` makes, so the mode it picks can be
/// asserted without a platform channel actually opening anything.
const MethodChannel _channel = MethodChannel('plugins.flutter.io/url_launcher');

class _LaunchRecorder {
  final List<({String url, String method})> calls = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add((url: (call.arguments as Map)['url'] as String, method: call.method));
      return true;
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

Future<void> _tapOpen(WidgetTester tester, {required bool embedded, required String url}) async {
  final prefs = PrefServiceCache(cache: {optionOpenLinksInEmbeddedBrowser: embedded});

  await tester.pumpWidget(PrefService(
    service: prefs,
    child: MaterialApp(
      home: Builder(
        builder: (context) => TextButton(onPressed: () => openUri(context, url), child: const Text('open')),
      ),
    ),
  ));

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final recorder = _LaunchRecorder();

  setUp(recorder.install);
  tearDown(() {
    recorder.remove();
    recorder.calls.clear();
  });

  testWidgets('with the option off, a link leaves for the default browser', (tester) async {
    await _tapOpen(tester, embedded: false, url: 'https://example.com/a');

    expect(recorder.calls, hasLength(1));
    expect(recorder.calls.single.url, 'https://example.com/a');
  });

  testWidgets('with the option on, the same link still launches', (tester) async {
    await _tapOpen(tester, embedded: true, url: 'https://example.com/a');

    expect(recorder.calls, hasLength(1));
    expect(recorder.calls.single.url, 'https://example.com/a');
  });

  testWidgets('this fork keeps stripping tracking parameters in both modes', (tester) async {
    const dirty = 'https://example.com/a?utm_source=x&keep=1';

    await _tapOpen(tester, embedded: false, url: dirty);
    await _tapOpen(tester, embedded: true, url: dirty);

    expect(recorder.calls.map((c) => c.url), everyElement('https://example.com/a?keep=1'));
  });
}
