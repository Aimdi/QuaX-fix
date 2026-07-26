import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/reddit/reddit_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Reddit's login page, watched for the redirect that carries the code back.
///
/// Pops the authorization code, or null when the reader backs out or declines.
/// Nothing is stored here — the caller trades the code for a refresh token, so
/// this screen never holds a credential.
class RedditLoginWebview extends StatefulWidget {
  final String clientId;

  /// Echoed back by Reddit and checked on return, so a code from anywhere else
  /// is ignored.
  final String state;

  const RedditLoginWebview({super.key, required this.clientId, required this.state});

  @override
  State<RedditLoginWebview> createState() => _RedditLoginWebviewState();
}

class _RedditLoginWebviewState extends State<RedditLoginWebview> {
  late final WebViewController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        // The redirect never resolves to a real page, so it has to be caught
        // as navigation rather than waited on as a load.
        onNavigationRequest: (request) => _handle(Uri.tryParse(request.url)),
        onUrlChange: (change) {
          final url = change.url;
          if (url != null) {
            _handle(Uri.tryParse(url));
          }
        },
      ))
      ..loadRequest(RedditAuth.authorizeUrl(clientId: widget.clientId, state: widget.state));
  }

  NavigationDecision _handle(Uri? uri) {
    if (uri == null || _finished) {
      return NavigationDecision.navigate;
    }

    final code = RedditAuth.codeFrom(uri, expectedState: widget.state);
    if (code != null) {
      _close(code);
      return NavigationDecision.prevent;
    }

    if (RedditAuth.deniedIn(uri)) {
      _close(null);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _close(String? code) {
    _finished = true;
    if (mounted) {
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).plugin_reddit_sign_in)),
      body: WebViewWidget(controller: _controller),
    );
  }
}
