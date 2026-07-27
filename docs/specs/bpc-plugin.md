# Bypass Paywalls (BPC) plugin

## Source

The uploaded `bpc.crx` is **Bypass Paywalls Clean** 4.4.0.0
(MIT, © magnolia1234). Upstream lives on GitFlic; Android browsers such as
Quetta can load the CRX directly. QuaX cannot.

## What cannot be ported

BPC's real unlocks are Chrome-only:

- `declarativeNetRequest` header rewrites and script blocking
- Per-site content scripts that rewrite the DOM / pull archive HTML
- Cookie clearing against the site's own jar

A Flutter app has none of those APIs, so embedding `background.js` /
`contentScript.js` would not work.

## What this plugin does instead

1. Ships the supported-domain list extracted from BPC's `sites.js` (+ custom /
   updated rules).
2. When the plugin is enabled, `openWithPlugins` claims outbound http(s) links
   whose host (or a parent domain) is on that list.
3. Opens an in-app WebView with one of three mobile strategies:
   - **Archive.today** (default) — `https://archive.ph/?url=…`
   - **12ft.io** — `https://12ft.io/{url}`
   - **Googlebot WebView** — original URL with a Googlebot User-Agent

The reader always keeps an "Open original" action that falls back to the normal
browser path.

## Plugin store

- Id: `bpc`
- Prefs: `plugin.bpc.enabled` (off by default), `plugin.bpc.strategy`
- Settings screen: strategy picker, site count, attribution link
- No home tab — it only changes how article links from posts open
