## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without posting, keep what you follow on your own device — with the plugins and
fixes below on top. Nothing here adds compose, reply, quote, or like-on-X.

### Threads

**Followed accounts are real subscriptions now.** They lived in a table nothing
else read, so a Threads account couldn't join a group and its posts never
reached the home timeline. It's a subscription like any other now: pick it into
a group, and its posts interleave into that group's feed and — behind a setting,
off by default — into Following and For you.

**You can see who you follow.** The Threads tab shows your accounts along the
top and names them in the empty state, so an empty feed with three accounts in
it looks different from one with none.

**Threads posts look like X posts.** Same card shape as a tweet — avatar down
the left, name and a quieter handle · time line beside it, then text and media —
so a Threads post in a mixed timeline reads as one of the row.

**Reading spends your session sparingly.** Meta bans sessions that behave like
scripts, so requests now leave one at a time with a little jitter, a throttle is
remembered past a restart, followed-account ids are looked up once instead of
searched for every refresh, and the tab, the home timeline and every group feed
share one cache. The safest setup is still an RSSHub instance or the guest path
rather than a pasted session — that session is the only thing that can cost you
the account.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
