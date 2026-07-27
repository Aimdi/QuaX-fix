import 'package:http/http.dart' as http;
import 'package:quax/plugins/bpc/bpc_strategy.dart';

/// Browser-like UA for archive.is fetches (bot UAs are often rate-limited).
const bpcArchiveUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0.0.0 Mobile Safari/537.36';

/// Resolves BPC `ref` aliases the same way Chrome's background.js does.
String? resolveBpcReferer(String? referer) {
  if (referer == null || referer.isEmpty) return null;
  return switch (referer) {
    'google' => bpcGoogleReferer,
    'facebook' => 'https://www.facebook.com/',
    'twitter' => 'https://t.co/',
    _ => referer,
  };
}

/// Result of a `getExtSrc` fetch (archive snapshot or other external HTML).
class BpcExtSrcResult {
  final String url;
  final String urlSrc;
  final String html;

  const BpcExtSrcResult({
    required this.url,
    required this.urlSrc,
    required this.html,
  });
}

/// Fetches external HTML for BPC content scripts, mirroring background.js
/// `getExtSrc`: follow archive search pages (`TEXT-BLOCK`) to the snapshot.
Future<BpcExtSrcResult> fetchBpcExtSrc({
  required String requestUrl,
  required String articleUrl,
  http.Client? client,
  String? userAgent,
  Map<String, String>? extraHeaders,
  int maxHops = 4,
}) async {
  final owned = client == null;
  final c = client ?? http.Client();
  try {
    var urlSrc = requestUrl;
    var html = '';
    for (var hop = 0; hop < maxHops; hop++) {
      final response = await c.get(
        Uri.parse(urlSrc),
        headers: {
          'User-Agent': userAgent ?? bpcArchiveUserAgent,
          'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
          'Referer': bpcGoogleReferer,
          ...?extraHeaders,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        html = '';
        break;
      }
      html = response.body;

      // Archive search URLs (`archive.ph/https://…`) are not article HTML.
      // Follow TEXT-BLOCK to the snapshot, or clear like background.js when
      // no hit is listed yet.
      if (_isArchiveSearchUrl(requestUrl, urlSrc)) {
        final next = _archiveSnapshotHref(html: html);
        if (next == null) {
          html = '';
          break;
        }
        urlSrc = next;
        html = '';
        continue;
      }
      break;
    }
    return BpcExtSrcResult(url: articleUrl, urlSrc: urlSrc, html: html);
  } catch (_) {
    return BpcExtSrcResult(url: articleUrl, urlSrc: requestUrl, html: '');
  } finally {
    if (owned) {
      c.close();
    }
  }
}

bool _isArchiveSearchUrl(String requestUrl, String urlSrc) {
  return requestUrl.startsWith('https://archive.') && urlSrc.contains('/https');
}

/// When archive returns a search hit list, background.js reads the first
/// `TEXT-BLOCK` link and fetches that snapshot next.
String? _archiveSnapshotHref({required String html}) {
  if (!html.contains('<div class="TEXT-BLOCK"')) return null;

  final after = html.split('<div class="TEXT-BLOCK"');
  if (after.length < 2) return null;
  final block = after[1].split('</div>').first;
  final hrefParts = block.split('href="');
  if (hrefParts.length < 2) return null;
  final href = hrefParts[1].split('"').first.trim();
  if (href.isEmpty) return null;
  return href;
}
