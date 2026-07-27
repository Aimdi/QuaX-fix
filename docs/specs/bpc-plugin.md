# Bypass Paywalls (BPC) plugin

## Source

The uploaded `bpc.crx` is **Bypass Paywalls Clean** 4.4.0.0
(MIT, © magnolia1234).

## Chrome → QuaX mapping

| Chrome (BPC) | QuaX rewrite |
|---|---|
| `declarativeNetRequest` script blocks | `shouldInterceptRequest` via `flutter_inappwebview` |
| UA / Referer rewrites | Per-site rule from `site_rules.json` |
| Cookie clearing | `CookieManager.deleteAllCookies` when the rule asks |
| `contentScript.js` + `cs_local/*` | Bundled as assets, injected at document-start |
| `chrome.runtime` messaging | `assets/bpc/cs/runtime_shim.js` + Dart `bpcRuntime` handler |
| `bg2csData` from background.js | Built in Dart from the site rule (`toBg2csData`) |
| `getExtSrc` / `getExtFetch` (archive / JSON) | Dart `http.get`, result delivered via `__bpcDeliver` |

## In-app engine (default)

1. When the plugin is enabled, claim **all** external http(s) links except X/Twitter hosts.
2. Resolve redirects first (so `ft.trib.al/…` becomes `ft.com/…`) before matching rules.
3. Look up `assets/bpc/site_rules.json` (parent-domain walk). Unknown hosts still open in the WebView without site-specific rules.
4. Open `InAppWebView` on the **resolved** URL with rule UA / referer / cookie clear.
5. Inject, in order: runtime shim → purify → `contentScript.js` → locale `cs_local` → generic unhide.
6. On load start/stop, deliver `{msg: "bg2cs", data: …}` so `cs_default` and `run_custom` run; re-match the site rule if the host changes.
7. Answer content-script `sendMessage` calls (archive fetch, cookie clear, reload) from Dart.

Locale bundle selection mirrors `background.js` (`bpc_cs_locale.dart`).

## Fallbacks

Archive.today / 12ft.io / bare Googlebot remain in settings for sites that still lock.
