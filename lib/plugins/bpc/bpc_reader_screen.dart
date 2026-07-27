import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/bpc/bpc_strategy.dart';
import 'package:quax/utils/urls.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app reader that opens a paywalled article through the chosen BPC strategy.
class BpcReaderScreen extends StatefulWidget {
  final String articleUrl;
  final BpcStrategy strategy;

  const BpcReaderScreen({
    super.key,
    required this.articleUrl,
    required this.strategy,
  });

  @override
  State<BpcReaderScreen> createState() => _BpcReaderScreenState();
}

class _BpcReaderScreenState extends State<BpcReaderScreen> {
  late final WebViewController _controller;
  late final Uri _loadUri;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUri = bpcReaderUri(widget.articleUrl, widget.strategy);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );

    if (widget.strategy == BpcStrategy.googlebot) {
      _controller.setUserAgent(bpcGooglebotUserAgent);
    }
    _controller.loadRequest(_loadUri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_bpc_reader_title),
        actions: [
          IconButton(
            tooltip: l10n.plugin_bpc_open_original,
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openUri(context, widget.articleUrl),
          ),
          IconButton(
            tooltip: l10n.share_link,
            icon: const Icon(Icons.share_outlined),
            onPressed: () => Share.share(widget.articleUrl),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
