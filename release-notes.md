## QuaX-fix

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without an account of X's choosing, keep what you follow on your own device —
with the plugins, feeds and fixes below on top.

### What's new

**Stocks.** A tab of its own, off until you install it. A reel of price cards
across the top, then each symbol at the size a market page gives it: the price
large, the day's move beside it, the line drawn against the previous close, and
the volume and the year's high and low underneath. Tickers are a subscription
like any other, so they can join a group.

**The ticker chart, readable.** Both axes are labelled, and dragging across the
chart reports the price under your finger instead of only the latest one.
Cashtags that are spoken one way and quoted another — `$SPX`, `$DAX`, `$BTC` —
now find their symbol instead of charting as "no data".

**Plugins are published, not just shipped.** The plugin store reads its list
from `plugins.json` in this repository, so a plugin can be added or withdrawn
without a new APK. Uninstalling one now deletes what it saved: its
subscriptions, the group entries pointing at them, its cache on disk and its
settings — including the Reddit sign-in and the Deepmarks signing key. Each
installed plugin says what it is currently holding.

**Substack.** A paid post that gives away its opening now shows that opening,
with a note where the free part ends, instead of a lock over an article you were
sent. Reading aloud lets you pick the engine and the voice, so an installed
speech engine of your own is actually used.

**Reddit.** The feed carries the same bar wherever it appears — sort, search,
add a subreddit, manage them — rather than only in its own tab.

**Links open inside the app** by default, instead of handing you to a browser.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/QuaX-fix)

This fork is signed with its own key, so Android will not update an install of
upstream QuaX in place — and upstream will not update this one. Pick one.
