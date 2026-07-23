import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/substack/substack_client.dart';
import 'package:quax/plugins/substack/substack_models.dart';
import 'package:quax/plugins/substack/substack_store.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/urls.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SubstackReaderScreen extends StatefulWidget {
  final SubstackPost post;

  const SubstackReaderScreen({super.key, required this.post});

  @override
  State<SubstackReaderScreen> createState() => _SubstackReaderScreenState();
}

class _SubstackReaderScreenState extends State<SubstackReaderScreen> {
  late final WebViewController _controller;
  late SubstackPost _post;
  Object? _error;
  var _loading = true;
  var _empty = false;
  var _paywalled = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubstackReadStore>().markRead(_post.id);
      _load();
    });
  }

  Future<void> _load() async {
    try {
      final client = context.read<SubstackClient>();
      final full = await client.fetchPost(_post.publication, _post.slug);
      if (!mounted) return;
      _post = full;
      _error = null;
      await _showContent(full);
    } catch (e) {
      if (!mounted) return;
      if (_post.canonicalUrl != null) {
        _error = null;
        _paywalled = false;
        _empty = false;
        _controller.setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ));
        await _controller.loadRequest(Uri.parse(_post.canonicalUrl!));
      } else {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _showContent(SubstackPost post) async {
    if (post.isPaywalled) {
      setState(() {
        _paywalled = true;
        _empty = false;
        _loading = false;
      });
      return;
    }

    final html = post.bodyHtml;
    if (html != null && html.trim().isNotEmpty) {
      _paywalled = false;
      _empty = false;
      _controller.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ));
      final scheme = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      await _controller.loadHtmlString(
        wrapSubstackHtml(
          title: post.title,
          body: html,
          subtitle: post.excerpt,
          authorName: post.authorName,
          publicationName: post.publicationName,
          background: _cssColor(scheme.surface),
          foreground: _cssColor(scheme.onSurface),
          muted: _cssColor(scheme.onSurfaceVariant),
          link: _cssColor(scheme.primary),
          isDark: isDark,
        ),
      );
      return;
    }

    if (post.canonicalUrl != null) {
      _paywalled = false;
      _empty = false;
      _controller.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ));
      await _controller.loadRequest(Uri.parse(post.canonicalUrl!));
      return;
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _empty = true;
        _paywalled = false;
      });
    }
  }

  void _share() {
    final url = _post.canonicalUrl;
    if (url == null || url.isEmpty) return;
    Share.share('${_post.title}\n$url');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_post.canonicalUrl != null) ...[
            IconButton(
              tooltip: L10n.of(context).plugin_substack_share,
              icon: const Icon(Icons.share_outlined),
              onPressed: _share,
            ),
            IconButton(
              tooltip: L10n.of(context).open_in_browser,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openUri(_post.canonicalUrl!),
            ),
          ],
        ],
      ),
      body: _error != null
          ? FullPageErrorWidget(
              error: _error,
              stackTrace: null,
              prefix: L10n.of(context).plugin_substack_load_error,
              onRetry: () {
                setState(() {
                  _error = null;
                  _empty = false;
                  _paywalled = false;
                  _loading = true;
                });
                _load();
              },
            )
          : _paywalled
              ? _PaywallPane(
                  post: _post,
                  onOpenWeb: _post.canonicalUrl == null ? null : () => openUri(_post.canonicalUrl!),
                )
              : _empty
                  ? Center(child: Text(L10n.of(context).plugin_substack_no_content))
                  : Stack(
                      children: [
                        WebViewWidget(controller: _controller),
                        if (_loading) const Center(child: CircularProgressIndicator()),
                      ],
                    ),
    );
  }
}

class _PaywallPane extends StatelessWidget {
  final SubstackPost post;
  final VoidCallback? onOpenWeb;

  const _PaywallPane({required this.post, this.onOpenWeb});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          L10n.of(context).plugin_substack_paywalled_title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          L10n.of(context).plugin_substack_paywalled_description,
          textAlign: TextAlign.center,
        ),
        if (post.excerpt != null) ...[
          const SizedBox(height: 24),
          Text(post.excerpt!, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
        if (onOpenWeb != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onOpenWeb,
            icon: const Icon(Icons.open_in_new),
            label: Text(L10n.of(context).open_in_browser),
          ),
        ],
      ],
    );
  }
}

String _cssColor(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2)}';
}

@visibleForTesting
String wrapSubstackHtml({
  required String title,
  required String body,
  required String background,
  required String foreground,
  required String muted,
  required String link,
  required bool isDark,
  String? subtitle,
  String? authorName,
  String? publicationName,
}) {
  final meta = [
    if (publicationName != null && publicationName.isNotEmpty) _escape(publicationName),
    if (authorName != null && authorName.isNotEmpty) _escape(authorName),
  ].join(' · ');

  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="color-scheme" content="${isDark ? 'dark' : 'light'}" />
<style>
  :root { color-scheme: ${isDark ? 'dark' : 'light'}; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    padding: 16px;
    line-height: 1.6;
    color: $foreground;
    background: $background;
    margin: 0;
  }
  img, video, iframe { max-width: 100%; height: auto; }
  h1 { font-size: 1.55rem; line-height: 1.25; margin: 0 0 8px; }
  .meta { color: $muted; font-size: 0.9rem; margin-bottom: 8px; }
  .subtitle { color: $muted; font-size: 1.05rem; margin: 0 0 20px; }
  a { color: $link; }
  blockquote {
    margin: 16px 0;
    padding-left: 12px;
    border-left: 3px solid $muted;
    color: $muted;
  }
  pre, code {
    background: ${isDark ? '#1E1E1E' : '#F2F2F2'};
    border-radius: 6px;
  }
  pre { padding: 12px; overflow-x: auto; }
  code { padding: 1px 4px; }
</style>
</head>
<body>
<h1>${_escape(title)}</h1>
${meta.isEmpty ? '' : '<div class="meta">$meta</div>'}
${subtitle == null || subtitle.isEmpty ? '' : '<p class="subtitle">${_escape(subtitle)}</p>'}
$body
</body>
</html>
''';
}

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
