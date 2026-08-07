## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without posting, keep what you follow on your own device — with the plugins and
fixes below on top. Nothing here adds compose, reply, quote, or like-on-X.

### X replies that keep loading

**Follow-up TweetDetail pages that only append via TimelineAddToModule now show
up as replies.** New tweets under a repeated conversationthread id are kept,
show-more on a parent-only first page is followed automatically, and zen mode
keeps paging while replies are collapsed.

### Expand compact Reposts

**Consecutive reposts stay as the small horizontal row by default.** Expand
turns that run into full timeline posts in place; Collapse puts the cards back.

### Bluesky: import, lists, likes, groups

**Import following from a public handle and import a public list** into local
subscriptions. Follower and following counts on a profile are tappable.
**Device-only likes** get a Liked tab (never written to Bluesky). **Bluesky
accounts can sit in groups**, with a blue butterfly badge so they stay distinct
from X posts.

### Faster Pixiv and safer Threads loads

**Pixiv refreshes tokens once under concurrency**, pages earlier, and stops
spinners that never ended. **Threads** shares profile HTML fetches, caps decode
work, and keeps guest GraphQL from hammering Meta when a cookie session is
cooling down.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
