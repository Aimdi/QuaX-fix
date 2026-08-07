## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without posting, keep what you follow on your own device — with the plugins and
fixes below on top. Nothing here adds compose, reply, quote, or like-on-X.

### What's new

**Calmer reading.** Thread replies draw a connector from avatar to avatar and
stop indenting after two levels with “Continue thread”. Consecutive reposts
collapse into one horizontal row. Calm mode hides engagement counts without
zen’s other caps. Sensitive media can remember “always show”. Groups show their
mark, colour and member count. Mixed Reddit/Substack cards get a thin brand
strip so origins stay glanceable.

**Your filters.** Quiet accounts (cap how many posts someone can dump into a
load), language hide/fold, and muted keywords that can expire or fold. Antennas
listen for keywords as their own feeds. Long-press a hashtag to follow it as a
topic search. Optional: subscription packs, a multi-column Deck, private profile
notes, and searchable notes on saved posts.

**Pixiv.** Sign in with Pixiv in the app (browser login, same idea as Pixez) —
no more pasting a refresh token unless you want to. Still read-only following.

**Alt text.** When X sends it, media shows an ALT badge; long-press to read it.

### Fixed

Timeline “Oops” crashes from missing `display_text_range` and media-only posts,
interleaved feed layout crashes, wrong caught-up restore after leaving a group,
Popular feeds scrambled by quiet-account caps, fold filters not sticking across
pages, and Pixiv load-more failing when the access token expires. Language
filter no longer saves mid-typing or offers Hide with an empty list. Always-show
sensitive media can be turned off again in Settings.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
