import 'package:quax/plugins/bpc/bpc_domains.dart';

/// Host of [url] with a leading `www.` stripped, or null when unparseable.
String? bpcHostFor(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return null;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// Whether [url] points at a site BPC knows how to help with.
///
/// Matches the host itself and any parent domain in [bpcSupportedDomains], so
/// `www.nytimes.com` and `cooking.nytimes.com` both hit `nytimes.com` when that
/// domain is listed.
bool isBpcSupportedUrl(String url, {Set<String> domains = bpcSupportedDomains}) {
  final host = bpcHostFor(url);
  if (host == null) return false;
  if (domains.contains(host)) return true;

  final parts = host.split('.');
  for (var i = 1; i < parts.length - 1; i++) {
    final candidate = parts.sublist(i).join('.');
    if (domains.contains(candidate)) return true;
  }
  return false;
}
