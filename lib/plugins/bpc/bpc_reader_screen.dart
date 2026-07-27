import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/bpc/bpc_cs_locale.dart';
import 'package:quax/plugins/bpc/bpc_ext_fetch.dart';
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
  InAppWebViewController? _controller;
  BpcRuleBook? _book;
  BpcSiteRule? _rule;
  List<UserScript> _userScripts = const [];
  late String _articleUrl;
  var _loading = true;
  var _ready = false;
  String? _error;

  bool get _useEngine =>
      widget.strategy == BpcStrategy.inApp || widget.strategy == BpcStrategy.googlebot;

  @override
  void initState() {
    super.initState();
    _articleUrl = widget.articleUrl;
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final book = await BpcRuleBook.load();
      final rule = book.ruleForUrl(_articleUrl);
      final scripts = _useEngine ? await _loadUserScripts(_articleUrl) : <UserScript>[];
      if (!mounted) return;
      setState(() {
        _book = book;
        _rule = rule;
        _userScripts = scripts;
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

  Future<void> _syncRuleFor(String url) async {
    final book = _book;
    if (book == null || !_useEngine) return;
    final next = book.ruleForUrl(url);
    if (next?.domain == _rule?.domain && next?.blockRegex == _rule?.blockRegex) {
      return;
    }
    if (!mounted) return;
    setState(() => _rule = next);
  }

  Future<List<UserScript>> _loadUserScripts(String articleUrl) async {
    final shim = await rootBundle.loadString('assets/bpc/cs/runtime_shim.js');
    final purify = await rootBundle.loadString('assets/bpc/cs/purify.min.js');
    final content = await rootBundle.loadString('assets/bpc/cs/contentScript.js');
    final local = await rootBundle.loadString(bpcCsLocalAssetFor(articleUrl));
    final ftAssist = await rootBundle.loadString('assets/bpc/ft_assist.js');
    final unhide = await rootBundle.loadString('assets/bpc/unhide.js');

    // document_start: beat paywall scripts that our interceptor may miss.
    // document_end: FT assist + generic unhide as a second pass.
    return [
      UserScript(
        source: shim,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
        groupName: 'bpc',
      ),
      UserScript(
        source: purify,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
        groupName: 'bpc',
      ),
      UserScript(
        source: content,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
        groupName: 'bpc',
      ),
      UserScript(
        source: local,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
        groupName: 'bpc',
      ),
      UserScript(
        source: ftAssist,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: true,
        groupName: 'bpc',
      ),
      UserScript(
        source: unhide,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: true,
        groupName: 'bpc',
      ),
    ];
  }

  Future<void> _beforeLoad() async {
    if (widget.strategy != BpcStrategy.inApp) return;
    final rule = _rule;
    if (rule?.dropCookies == null) return;
    await CookieManager.instance().deleteAllCookies();
  }

  Future<void> _deliverBg2cs(InAppWebViewController controller) async {
    if (!_useEngine) return;
    final data = _rule?.toBg2csData() ?? {'optin_fetch': 1};
    final payload = jsonEncode({'msg': 'bg2cs', 'data': data});
    try {
      await controller.evaluateJavascript(
        source: 'window.__bpcDeliver && window.__bpcDeliver($payload);',
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _onRuntimeMessage(List<dynamic> args) async {
    if (args.isEmpty) return null;
    final raw = args.first;
    if (raw is! Map) return null;
    final msg = Map<String, dynamic>.from(raw);
    final request = msg['request'] as String?;
    final data = msg['data'];
    final controller = _controller;
    if (controller == null || request == null) return null;

    if (request == 'refreshCurrentTab') {
      await controller.reload();
      return null;
    }
    if (request == 'clear_cookies_domain') {
      await CookieManager.instance().deleteAllCookies();
      return null;
    }
    if (request == 'getExtSrc' && data is Map) {
      return _fetchExtSrc(Map<String, dynamic>.from(data));
    }
    if (request == 'getExtFetch' && data is Map) {
      return _fetchExtFetch(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<Map<String, dynamic>> _fetchExtSrc(Map<String, dynamic> data) async {
    final url = data['url'] as String? ?? '';
    final result = url.isEmpty
        ? BpcExtSrcResult(url: _articleUrl, urlSrc: url, html: '')
        : await fetchBpcExtSrc(
            requestUrl: url,
            articleUrl: _articleUrl,
            userAgent: bpcArchiveUserAgent,
          );
    // Returned to the runtime shim (avoids evaluateJavascript size limits).
    return {
      'msg': 'showExtSrc',
      'data': {
        'url': result.url,
        'url_src': result.urlSrc,
        'html': result.html,
        'selector': data['selector'],
        'selector_source': data['selector_source'],
        'selector_archive': data['selector_archive'],
        'text_fail': data['text_fail'],
      },
    };
  }

  Future<Map<String, dynamic>> _fetchExtFetch(Map<String, dynamic> data) async {
    final url = data['url'] as String?;
    var html = '';
    if (url != null) {
      try {
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': _userAgent ?? bpcArchiveUserAgent,
          'Referer': bpcGoogleReferer,
        });
        if (response.statusCode >= 200 && response.statusCode < 300) {
          html = response.body;
        }
      } catch (_) {}
    }
    return {
      'msg': 'showExtFetch',
      'data': {
        'url': url,
        'html': html,
        'data_ext_fetch_id': data['data_ext_fetch_id'],
      },
    };
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
      final ref = _rule?.resolvedReferer;
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
    return WebResourceResponse(
      contentType: 'text/plain',
      data: Uint8List(0),
      statusCode: 200,
      reasonPhrase: 'OK',
    );
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
            onPressed: () => openUri(context, _articleUrl),
          ),
          IconButton(
            tooltip: l10n.share_link,
            icon: const Icon(Icons.share_outlined),
            onPressed: () => SharePlus.instance.share(ShareParams(text: _articleUrl)),
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
                        url: WebUri(bpcReaderUri(_articleUrl, widget.strategy).toString()),
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
                      initialUserScripts: UnmodifiableListView(_userScripts),
                      onWebViewCreated: (controller) async {
                        _controller = controller;
                        controller.addJavaScriptHandler(
                          handlerName: 'bpcRuntime',
                          callback: (args) async => _onRuntimeMessage(args),
                        );
                        await _beforeLoad();
                      },
                      shouldInterceptRequest: _intercept,
                      onLoadStart: (controller, url) async {
                        if (url != null) {
                          await _syncRuleFor(url.toString());
                        }
                        if (mounted) setState(() => _loading = true);
                        await _deliverBg2cs(controller);
                      },
                      onLoadStop: (controller, url) async {
                        if (url != null) {
                          await _syncRuleFor(url.toString());
                        }
                        await _deliverBg2cs(controller);
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
