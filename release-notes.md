## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without posting, keep what you follow on your own device — with the plugins and
fixes below on top. Nothing here adds compose, reply, quote, or like-on-X.

### Threads posts from Accounts

**Followed Threads Accounts show posts again.** Guest mode was scraping HTML
that Meta often leaves empty; it now loads the public GraphQL profile threads
query (with HTML as a fallback). If you paste cookies and a Bearer token,
Accounts still load first — a dead session no longer parks the whole tab for
half an hour, and cookie failures fall back to that same public path. Bearer
home/For You uses the current Instagram timeline parameters when you have no
local Accounts added.

Add people under the Threads tab (local Accounts). Login alone does not create
that list.

### Comments and quotes

**Conversation and quote screens work again.** X had rotated the GraphQL query
ids for TweetDetail and SearchTimeline. This build ships the new ids, and
`endpoints.json` on main repairs older installs on the next cold start.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
