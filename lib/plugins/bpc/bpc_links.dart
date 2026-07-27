import 'package:http/http.dart' as http;
import 'package:quax/plugins/bpc/bpc_domains.dart';

/// Hosts that must stay out of the BPC reader (handled by QuaX / the browser).
const _bpcSkippedHosts = {
  'x.com',
  'www.x.com',
  'twitter.com',
  'www.twitter.com',
  'mobile.twitter.com',
};

/// Host of [url] with a leading `www.` stripped, or null when unparseable.
String? bpcHostFor(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return null;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// Whether [url] is an external http(s) link the BPC reader may claim.
///
/// X / Twitter hosts are excluded so profile and status links are not swallowed
/// by the article WebView.
bool isBpcClaimableUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;
  if (_bpcSkippedHosts.contains(host)) return false;
  return true;
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

/// Follows redirects so shorteners like `ft.trib.al/…` become the real article.
///
/// Returns [url] unchanged when it is already a known BPC host, when redirects
/// cannot be followed, or when a hop lands on an X host (caller should not
/// open that in the reader).
Future<String> resolveBpcArticleUrl(
  String url, {
  http.Client? client,
  int maxHops = 8,
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (isBpcSupportedUrl(url)) {
    return url;
  }

  final owned = client == null;
  final c = client ?? http.Client();
  try {
    var current = url;
    for (var i = 0; i < maxHops; i++) {
      final uri = Uri.tryParse(current);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return current;
      }

      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await c.send(request).timeout(timeout);
      // Drain without reading the body into memory.
      await response.stream.drain<void>();

      final status = response.statusCode;
      if (status >= 300 && status < 400) {
        final loc = response.headers['location'];
        if (loc == null || loc.isEmpty) {
          return current;
        }
        current = uri.resolve(loc).toString();
        if (isBpcSupportedUrl(current)) {
          return current;
        }
        continue;
      }
      return current;
    }
    return current;
  } catch (_) {
    return url;
  } finally {
    if (owned) {
      c.close();
    }
  }
}
