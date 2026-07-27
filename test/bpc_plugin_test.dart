import 'package:flutter_test/flutter_test.dart';
import 'package:quax/plugins/bpc/bpc_domains.dart';
import 'package:quax/plugins/bpc/bpc_links.dart';
import 'package:quax/plugins/bpc/bpc_plugin.dart';
import 'package:quax/plugins/bpc/bpc_strategy.dart';
import 'package:quax/plugins/plugin_registry.dart';

void main() {
  group('isBpcSupportedUrl', () {
    test('matches listed hosts and www variants', () {
      expect(isBpcSupportedUrl('https://www.nytimes.com/2024/01/01/world/example.html'), isTrue);
      expect(isBpcSupportedUrl('https://nytimes.com/article'), isTrue);
      expect(isBpcSupportedUrl('http://bloomberg.com/news/x'), isTrue);
    });

    test('matches subdomains of a listed parent', () {
      expect(isBpcSupportedUrl('https://cooking.nytimes.com/recipes/123'), isTrue);
    });

    test('rejects unrelated hosts and non-http schemes', () {
      expect(isBpcSupportedUrl('https://example.com/post'), isFalse);
      expect(isBpcSupportedUrl('https://x.com/someone/status/1'), isFalse);
      expect(isBpcSupportedUrl('mailto:editor@nytimes.com'), isFalse);
      expect(isBpcSupportedUrl('not a url'), isFalse);
    });

    test('honours an injected domain set', () {
      const tiny = {'paywall.test'};
      expect(isBpcSupportedUrl('https://paywall.test/a', domains: tiny), isTrue);
      expect(isBpcSupportedUrl('https://nytimes.com/a', domains: tiny), isFalse);
    });
  });

  group('bpcReaderUri', () {
    const article = 'https://www.ft.com/content/abc';

    test('archive strategy searches archive.ph', () {
      final uri = bpcReaderUri(article, BpcStrategy.archive);
      expect(uri.host, 'archive.ph');
      expect(uri.queryParameters['url'], article);
    });

    test('twelveFt strategy prefixes 12ft.io', () {
      final uri = bpcReaderUri(article, BpcStrategy.twelveFt);
      expect(uri.toString(), 'https://12ft.io/$article');
    });

    test('googlebot strategy keeps the original URL', () {
      expect(bpcReaderUri(article, BpcStrategy.googlebot).toString(), article);
    });
  });

  group('parseBpcStrategy', () {
    test('defaults to archive', () {
      expect(parseBpcStrategy(null), BpcStrategy.archive);
      expect(parseBpcStrategy('nope'), BpcStrategy.archive);
    });

    test('round-trips pref values', () {
      for (final strategy in BpcStrategy.values) {
        expect(parseBpcStrategy(bpcStrategyPrefValue(strategy)), strategy);
      }
    });
  });

  test('BPC ships in the plugin store with a settings screen', () {
    expect(builtInPlugins.any((p) => p is BpcPlugin), isTrue);
    expect(bpcSupportedDomains.length, greaterThan(1000));
    expect(bpcSupportedDomains.contains('nytimes.com'), isTrue);
  });
}
