import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/bpc/bpc_rules.dart';
import 'package:quax/plugins/bpc/bpc_strategy.dart';
import 'package:quax/utils/urls.dart';
import 'package:share_plus/share_plus.dart';

/// In-app reader that applies BPC tactics (or a proxy fallback) to [articleUrl].
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
  BpcSiteRule? _rule;
  String? _unhideJs;
  var _loading = true;
  var _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final book = await BpcRuleBook.load();
      final unhide = await rootBundle.loadString('assets/bpc/unhide.js');
      if (!mounted) return;
      setState(() {
        _rule = book.ruleForUrl(widget.articleUrl);
        _unhideJs = unhide;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _ready = true;
      });
    }
  }

  Future<void> _beforeLoad() async {
    if (widget.strategy != BpcStrategy.inApp) return;
    final rule = _rule;
    if (rule == null) return;

    final cookies = CookieManager.instance();
    if (rule.dropCookies != null) {
      // BPC clears the jar for the site (or selected names). Clearing all
      // WebView cookies is blunt but matches the extension's common path and
      // avoids leaving a metered session that re-locks the article.
      await cookies.deleteAllCookies();
    }
  }

  String? get _userAgent {
    return switch (widget.strategy) {
      BpcStrategy.googlebot => bpcGooglebotUserAgent,
      BpcStrategy.inApp => _rule?.resolvedUserAgent,
      _ => null,
    };
  }

  Map<String, String> get _headers {
    if (widget.strategy == BpcStrategy.inApp) {
      final ref = _rule?.referer;
      if (ref != null && ref.isNotEmpty) {
        return {'Referer': ref};
      }
      if (_rule?.resolvedUserAgent != null) {
        return {'Referer': bpcGoogleReferer};
      }
    }
    if (widget.strategy == BpcStrategy.googlebot) {
      return {'Referer': bpcGoogleReferer};
    }
    return const {};
  }

  Future<WebResourceResponse?> _intercept(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    if (widget.strategy != BpcStrategy.inApp) return null;
    final rule = _rule;
    if (rule == null) return null;
    final url = request.url.toString();
    if (!rule.blocksUrl(url)) return null;

    // Empty response == blocked, the DNR equivalent in a WebView.
    return WebResourceResponse(
      contentType: 'text/plain',
      data: Uint8List(0),
      statusCode: 200,
      reasonPhrase: 'OK',
    );
  }

  Future<void> _injectUnhide(InAppWebViewController controller) async {
    if (widget.strategy != BpcStrategy.inApp && widget.strategy != BpcStrategy.googlebot) {
      return;
    }
    final js = _unhideJs;
    if (js == null) return;
    try {
      await controller.evaluateJavascript(source: js);
    } catch (_) {
      // Page may have navigated away; ignore.
    }
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
            onPressed: () => SharePlus.instance.share(ShareParams(text: widget.articleUrl)),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(bpcReaderUri(widget.articleUrl, widget.strategy).toString()),
                        headers: _headers,
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        userAgent: _userAgent,
                        useShouldInterceptRequest: widget.strategy == BpcStrategy.inApp,
                        mediaPlaybackRequiresUserGesture: true,
                        transparentBackground: false,
                        isInspectable: kDebugMode,
                      ),
                      initialUserScripts: UnmodifiableListView([
                        if (_unhideJs != null &&
                            (widget.strategy == BpcStrategy.inApp ||
                                widget.strategy == BpcStrategy.googlebot))
                          UserScript(
                            source: _unhideJs!,
                            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                            forMainFrameOnly: true,
                          ),
                      ]),
                      onWebViewCreated: (controller) async {
                        await _beforeLoad();
                      },
                      shouldInterceptRequest: _intercept,
                      onLoadStart: (controller, url) {
                        if (mounted) setState(() => _loading = true);
                      },
                      onLoadStop: (controller, url) async {
                        await _injectUnhide(controller);
                        if (mounted) setState(() => _loading = false);
                      },
                      onReceivedError: (controller, request, error) {
                        if (mounted) setState(() => _loading = false);
                      },
                    ),
                    if (_loading) const LinearProgressIndicator(),
                  ],
                ),
    );
  }
}
