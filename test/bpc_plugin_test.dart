import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quax/plugins/bpc/bpc_cs_locale.dart';
import 'package:quax/plugins/bpc/bpc_domains.dart';
import 'package:quax/plugins/bpc/bpc_links.dart';
import 'package:quax/plugins/bpc/bpc_plugin.dart';
import 'package:quax/plugins/bpc/bpc_rules.dart';
import 'package:quax/plugins/bpc/bpc_strategy.dart';
import 'package:quax/plugins/plugin_registry.dart';

void main() {
  group('isBpcClaimableUrl', () {
    test('claims any external http(s) host', () {
      expect(isBpcClaimableUrl('https://ft.trib.al/6142iVp'), isTrue);
      expect(isBpcClaimableUrl('https://example.com/post'), isTrue);
      expect(isBpcClaimableUrl('https://www.ft.com/content/abc'), isTrue);
    });

    test('skips X hosts and non-http schemes', () {
      expect(isBpcClaimableUrl('https://x.com/someone/status/1'), isFalse);
      expect(isBpcClaimableUrl('https://twitter.com/someone'), isFalse);
      expect(isBpcClaimableUrl('mailto:editor@nytimes.com'), isFalse);
    });
  });

  group('resolveBpcArticleUrl', () {
    test('leaves known BPC hosts alone without a network hop', () async {
      final client = MockClient((_) async => fail('should not fetch'));
      final resolved = await resolveBpcArticleUrl(
        'https://www.ft.com/content/abc',
        client: client,
      );
      expect(resolved, 'https://www.ft.com/content/abc');
    });

    test('follows short-link redirects to the article host', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'ft.trib.al') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://www.ft.com/content/abc'},
          );
        }
        return http.Response('ok', 200);
      });
      final resolved = await resolveBpcArticleUrl(
        'https://ft.trib.al/6142iVp',
        client: client,
      );
      expect(resolved, 'https://www.ft.com/content/abc');
      expect(isBpcSupportedUrl(resolved), isTrue);
    });
  });

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

    test('in-app and googlebot keep the original URL', () {
      expect(bpcReaderUri(article, BpcStrategy.inApp).toString(), article);
      expect(bpcReaderUri(article, BpcStrategy.googlebot).toString(), article);
    });

    test('archive strategy searches archive.ph', () {
      final uri = bpcReaderUri(article, BpcStrategy.archive);
      expect(uri.host, 'archive.ph');
      expect(uri.queryParameters['url'], article);
    });

    test('twelveFt strategy prefixes 12ft.io', () {
      final uri = bpcReaderUri(article, BpcStrategy.twelveFt);
      expect(uri.toString(), 'https://12ft.io/$article');
    });
  });

  group('parseBpcStrategy', () {
    test('defaults to in-app', () {
      expect(parseBpcStrategy(null), BpcStrategy.inApp);
      expect(parseBpcStrategy('nope'), BpcStrategy.inApp);
    });

    test('round-trips pref values', () {
      for (final strategy in BpcStrategy.values) {
        expect(parseBpcStrategy(bpcStrategyPrefValue(strategy)), strategy);
      }
    });
  });

  group('BpcSiteRule', () {
    test('blocks paywall script URLs from the rule regex', () {
      const rule = BpcSiteRule(
        domain: 'theatlantic.com',
        blockRegex: r'\.theatlantic\.com\/zephr\/',
        allowCookies: true,
      );
      expect(rule.blocksUrl('https://www.theatlantic.com/zephr/feature.js'), isTrue);
      expect(rule.blocksUrl('https://cdn.theatlantic.com/article.js'), isFalse);
    });

    test('resolves googlebot and custom user agents', () {
      expect(
        const BpcSiteRule(domain: 'x.test', userAgent: 'googlebot').resolvedUserAgent,
        bpcGooglebotUserAgent,
      );
      expect(
        const BpcSiteRule(domain: 'x.test', userAgentCustom: 'CustomBot/1').resolvedUserAgent,
        'CustomBot/1',
      );
    });

    test('rule book walks parent domains', () {
      final book = BpcRuleBook.forTesting({
        'nytimes.com': const BpcSiteRule(
          domain: 'nytimes.com',
          userAgentCustom: 'Mozilla/5.0 (compatible; Google-InspectionTool/1.0)',
          blockRegex: r'meter\.js',
          allowCookies: true,
        ),
      });
      final rule = book.ruleForUrl('https://cooking.nytimes.com/recipes/1');
      expect(rule, isNotNull);
      expect(rule!.blocksUrl('https://www.nytimes.com/meter.js'), isTrue);
      expect(rule.resolvedUserAgent, contains('Google-InspectionTool'));
    });

    test('toBg2csData carries the fields content scripts expect', () {
      const rule = BpcSiteRule(
        domain: 'example.com',
        ampUnhide: true,
        clearLocalStorage: true,
        ldJson: 'div.paywall|article.body',
        csCode: '[{"hide_elem":".wall"}]',
      );
      final data = rule.toBg2csData();
      expect(data['optin_fetch'], 1);
      expect(data['amp_unhide'], 1);
      expect(data['cs_clear_lclstrg'], 1);
      expect(data['ld_json'], 'div.paywall|article.body');
      expect(data['cs_code'], '[{"hide_elem":".wall"}]');
    });
  });

  group('bpcCsLocalAssetFor', () {
    test('picks language bundles like the extension background page', () {
      expect(bpcCsLocalAssetFor('https://www.nytimes.com/a'), endsWith('contentScript_en.js'));
      expect(bpcCsLocalAssetFor('https://www.lemonde.fr/a'), endsWith('contentScript_fr.js'));
      expect(bpcCsLocalAssetFor('https://www.faz.net/a'), endsWith('contentScript_de.js'));
      expect(bpcCsLocalAssetFor('https://elpais.com/a'), endsWith('contentScript_es.pt.js'));
      expect(bpcCsLocalAssetFor('https://www.repubblica.it/a'), endsWith('contentScript_it.js'));
      expect(bpcCsLocalAssetFor('https://www.ad.nl/a'), endsWith('contentScript_nl.js'));
      expect(bpcCsLocalAssetFor('https://wyborcza.pl/a'), endsWith('contentScript_pl.js'));
      expect(bpcCsLocalAssetFor('https://www.dn.se/a'), endsWith('contentScript_fi.se.js'));
    });
  });

  test('BPC ships in the plugin store with a settings screen', () {
    expect(builtInPlugins.any((p) => p is BpcPlugin), isTrue);
    expect(bpcSupportedDomains.length, greaterThan(1000));
    expect(bpcSupportedDomains.contains('nytimes.com'), isTrue);
  });
}
