# Bypass Paywalls (BPC) plugin

## Source

The uploaded `bpc.crx` is **Bypass Paywalls Clean** 4.4.0.0
(MIT, © magnolia1234).

## What Chrome had that stock Flutter WebView lacked

| Chrome (BPC) | Why it mattered | QuaX rewrite |
|---|---|---|
| `declarativeNetRequest` block rules | Stop paywall JS before it runs | `shouldInterceptRequest` via `flutter_inappwebview` |
| Request header rewrite (UA / Referer) | Many sites serve full text to Googlebot | Per-rule `userAgent` + `Referer` on the WebView |
| Cookie clearing | Kill metered / soft-paywall sessions | `CookieManager.deleteAllCookies` when the rule drops cookies |
| Content scripts | Unhide DOM, AMP access, archive fetch | Bundled `assets/bpc/unhide.js` at document-end (+ re-inject on load) |
| `chrome.runtime` messaging + `cs_local/*` | Hundreds of site-specific JS helpers | Not ported — too tied to the extension mailbox; unhide + script block covers the common path |

## In-app engine (default)

1. Claim outbound links whose host is in `bpcSupportedDomains`.
2. Look up `assets/bpc/site_rules.json` for that host (parent-domain walk).
3. Open `InAppWebView` on the **original** URL with:
   - rule UA / Googlebot when set
   - Google referer when a bot UA is used
   - cookie clear when the rule asks
   - request interception matching `block_regex`
   - unhide user script
4. Fallbacks still available in settings: Archive.today, 12ft.io, bare Googlebot.

## Limits that remain

- Site-specific `cs_local` scripts and archive.is HTML swaps are not executed.
- Clearing cookies is WebView-global, not per-cookie-name like the extension.
- Some sites detect WebViews or require desktop Chrome quirks we cannot fake.

When the in-app engine fails on a site, switch that session to Archive or 12ft in plugin settings.
