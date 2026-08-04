import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/utils/browsers.dart';
import 'package:xta/utils/urls.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A long-form X article, read inside XTA.
///
/// Tapping one used to hand the reader to a browser — a custom tab at best,
/// which is still leaving the app: their tabs, their history, their session.
/// The article is the post's content, so it opens where the post did, with the
/// way out still offered rather than taken for them.
class ArticleScreen extends StatefulWidget {
  final String url;

  const ArticleScreen({super.key, required this.url});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(cleanUrl(widget.url)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.article_on_x, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.share_link,
            icon: const Icon(Icons.share_outlined),
            onPressed: () => SharePlus.instance.share(ShareParams(text: cleanUrl(widget.url))),
          ),
          // Still offered, because an article that will not render in here has
          // to be readable somewhere. Goes to the browser the reader chose, and
          // out of the app rather than into an embedded view — asking for a
          // browser is asking to leave.
          IconButton(
            tooltip: l10n.open_in_browser,
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openExternally(
              cleanUrl(widget.url),
              package: PrefService.of(context, listen: false).get<String>(optionExternalBrowser) ??
                  systemDefaultBrowser,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
