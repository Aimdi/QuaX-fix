import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/substack/substack_client.dart';
import 'package:quax/plugins/substack/substack_models.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/urls.dart';
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

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
    final html = post.bodyHtml;
    if (html != null && html.trim().isNotEmpty && !post.isPaywalled) {
      await _controller.loadHtmlString(_wrapHtml(post.title, html));
      return;
    }
    if (post.canonicalUrl != null) {
      await _controller.loadRequest(Uri.parse(post.canonicalUrl!));
      return;
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _empty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_post.canonicalUrl != null)
            IconButton(
              tooltip: L10n.of(context).open_in_browser,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openUri(_post.canonicalUrl!),
            ),
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
                  _loading = true;
                });
                _load();
              },
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

String _wrapHtml(String title, String body) {
  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1" />
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 16px; line-height: 1.5; color: #0F1419; }
  img, video { max-width: 100%; height: auto; }
  h1 { font-size: 1.4rem; }
</style>
</head>
<body>
<h1>${_escape(title)}</h1>
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
