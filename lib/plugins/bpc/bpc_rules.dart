import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:quax/plugins/bpc/bpc_links.dart';
import 'package:quax/plugins/bpc/bpc_strategy.dart';

/// Per-site rule extracted from Bypass Paywalls Clean.
class BpcSiteRule {
  final String domain;
  final String? userAgent;
  final String? userAgentCustom;
  final String? referer;
  final String? blockRegex;
  final List<String>? dropCookies;
  final bool allowCookies;
  final bool ampUnhide;
  final bool ampRedirect;
  final bool nofix;

  const BpcSiteRule({
    required this.domain,
    this.userAgent,
    this.userAgentCustom,
    this.referer,
    this.blockRegex,
    this.dropCookies,
    this.allowCookies = false,
    this.ampUnhide = false,
    this.ampRedirect = false,
    this.nofix = false,
  });

  factory BpcSiteRule.fromJson(Map<String, dynamic> json) {
    final drop = json['dc'];
    return BpcSiteRule(
      domain: json['d'] as String,
      userAgent: json['ua'] as String?,
      userAgentCustom: json['uac'] as String?,
      referer: json['ref'] as String?,
      blockRegex: json['b'] as String?,
      dropCookies: drop is List ? drop.cast<String>() : null,
      allowCookies: json['ac'] == 1,
      ampUnhide: json['au'] == 1,
      ampRedirect: json['ar'] == 1,
      nofix: json['nf'] == 1,
    );
  }

  /// Effective User-Agent for the in-app reader, if the rule asks for one.
  String? get resolvedUserAgent {
    if (userAgentCustom != null && userAgentCustom!.isNotEmpty) {
      return userAgentCustom;
    }
    if (userAgent == 'googlebot') {
      return bpcGooglebotUserAgent;
    }
    return null;
  }

  /// Whether this URL's resource request should be blocked (paywall script).
  bool blocksUrl(String url) {
    final pattern = blockRegex;
    if (pattern == null || pattern.isEmpty) return false;
    try {
      return RegExp(pattern, caseSensitive: false).hasMatch(url);
    } catch (_) {
      return false;
    }
  }
}

/// Loads and indexes BPC site rules from the bundled JSON asset.
class BpcRuleBook {
  BpcRuleBook._(this._byDomain);

  final Map<String, BpcSiteRule> _byDomain;

  static BpcRuleBook? _instance;

  static Future<BpcRuleBook> load() async {
    final existing = _instance;
    if (existing != null) return existing;

    final raw = await rootBundle.loadString('assets/bpc/site_rules.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final sites = decoded['sites'] as Map<String, dynamic>? ?? {};
    final byDomain = <String, BpcSiteRule>{
      for (final entry in sites.entries)
        entry.key: BpcSiteRule.fromJson(Map<String, dynamic>.from(entry.value as Map)),
    };
    return _instance = BpcRuleBook._(byDomain);
  }

  /// Visible for tests — builds a book without touching assets.
  factory BpcRuleBook.forTesting(Map<String, BpcSiteRule> byDomain) => BpcRuleBook._(byDomain);

  int get siteCount => _byDomain.length;

  /// Rule for [url], walking parent domains the same way link matching does.
  BpcSiteRule? ruleForUrl(String url) {
    final host = bpcHostFor(url);
    if (host == null) return null;
    final direct = _byDomain[host];
    if (direct != null) return direct;

    final parts = host.split('.');
    for (var i = 1; i < parts.length - 1; i++) {
      final candidate = parts.sublist(i).join('.');
      final rule = _byDomain[candidate];
      if (rule != null) return rule;
    }
    return null;
  }
}
