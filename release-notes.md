## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without posting, keep what you follow on your own device — with the plugins and
fixes below on top. Nothing here adds compose, reply, quote, or like-on-X.

### Spare accounts for rate limits only

**Turn off login accounts you only keep for higher limits.** Settings → Accounts
(or the manage-accounts icon on Following / For you) has an “Include in For you”
switch. Off keeps the account in the fetch rotation for profiles, search, and
Following chunks, but drops it from the merged For you HomeTimeline. Following
still uses your local subscriptions.

### Fediverse cards

**Mastodon posts look like the rest of the timeline.** Larger layout, reply /
boost / favourite counts, and article link previews from Mastodon’s PreviewCard.
Still read-only — taps open the status in the browser.

### Threads without login

**Add Accounts and read public posts — no cookies required.** Guest mode reads
the same public GraphQL the website uses when you’re logged out (and profiles
from the public page). Cookies, Bearer, RSSHub and Xy stay optional.

**Engagement on Threads cards:** reply and repost counts when Meta sends them,
plus a **local** like heart (device-only, never sent to Threads). Link/article
previews show when Meta attaches them.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
