import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:quax/plugins/bpc/bpc_ext_fetch.dart';
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
  final Object? ampRedirect;
  final bool nofix;
  final bool clearLocalStorage;
  final bool csBlock;
  final bool csDompurify;
  final Object? csCode;
  final Object? csParam;
  final String? ldJson;
  final String? ldJsonNext;
  final String? ldJsonSource;
  final String? ldJsonUrl;
  final String? ldArchiveIs;
  final String? ldOchToUnlock;

  const BpcSiteRule({
    required this.domain,
    this.userAgent,
    this.userAgentCustom,
    this.referer,
    this.blockRegex,
    this.dropCookies,
    this.allowCookies = false,
    this.ampUnhide = false,
    this.ampRedirect,
    this.nofix = false,
    this.clearLocalStorage = false,
    this.csBlock = false,
    this.csDompurify = false,
    this.csCode,
    this.csParam,
    this.ldJson,
    this.ldJsonNext,
    this.ldJsonSource,
    this.ldJsonUrl,
    this.ldArchiveIs,
    this.ldOchToUnlock,
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
      ampRedirect: json['ar'],
      nofix: json['nf'] == 1,
      clearLocalStorage: json['cl'] == 1,
      csBlock: json['cb'] == 1,
      csDompurify: json['dp'] == 1,
      csCode: json['cc'],
      csParam: json['cp'],
      ldJson: json['ld'] as String?,
      ldJsonNext: json['ldn'] as String?,
      ldJsonSource: json['lds'] as String?,
      ldJsonUrl: json['ldu'] as String?,
      ldArchiveIs: json['lda'] as String?,
      ldOchToUnlock: json['ldo'] as String?,
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

  /// Effective Referer header (`google` → `https://www.google.com/`, etc.).
  String? get resolvedReferer => resolveBpcReferer(referer);

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

  /// Payload the extension's background page would send as `{msg: bg2cs}`.
  Map<String, dynamic> toBg2csData() {
    final data = <String, dynamic>{
      // Always let the content scripts fetch through our runtime shim when they
      // ask — archive.is / JSON article bodies hang off this flag.
      'optin_fetch': 1,
    };
    if (ampUnhide) data['amp_unhide'] = 1;
    if (ampRedirect != null) data['amp_redirect'] = ampRedirect;
    if (csBlock) data['cs_block'] = 1;
    if (clearLocalStorage) data['cs_clear_lclstrg'] = 1;
    if (csCode != null) data['cs_code'] = csCode;
    if (csParam != null) data['cs_param'] = csParam;
    if (ldJson != null) data['ld_json'] = ldJson;
    if (ldJsonNext != null) data['ld_json_next'] = ldJsonNext;
    if (ldJsonSource != null) data['ld_json_source'] = ldJsonSource;
    if (ldJsonUrl != null) data['ld_json_url'] = ldJsonUrl;
    if (ldArchiveIs != null) data['ld_archive_is'] = ldArchiveIs;
    if (ldOchToUnlock != null) data['ld_och_to_unlock'] = ldOchToUnlock;
    return data;
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
