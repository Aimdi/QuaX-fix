## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without an account of X's choosing, keep what you follow on your own device —
with the plugins, feeds and fixes below on top.

### What's new

**A feed you can finish.** Catch-up mode, per feed and off until you turn it
on, shows what arrived since you last read and then stops, instead of scrolling
on forever. When it cannot see all the way back to where you were — X only lets
the app page so far — it says so rather than telling you you are done. Reaching
the end is also the only thing that moves your reading position now; it used to
drift whenever the list happened to sit near the top.

**Posts when the network is not there.** A feed that fails to load no longer
throws away the posts already on your phone. You get them, with a line saying
how old they are and why the refresh failed — rate limited, no working account,
or simply offline — and a retry.

**More places to read, still nothing to post.** Bluesky via the public AppView,
Mastodon through a home instance you choose, an optional private Pixiv following
feed (refresh token; hidden until you ask for private plugins), and Threads that
can use a pasted browser session or Bearer when you want Following without
RSSHub — guest pages and your own proxies stay as fallbacks. Substack got RSS
fallback, unread/free/podcast filters, public Notes discovery, and article
caching. The plugin store groups things by purpose and shows each plugin with a
brand mark.

**Stocks, Reddit.** The Stocks tab is closer to a StockTwits-style watchlist
feed. Reddit comment threads, For You refresh, and listing “Load more” share one
read session and fall back when OAuth is not enough.

**Mutes that stay muted.** Muted words, the content filter and the like and
repost thresholds used to apply only while a group was sorted one particular
way. They are the group's rules now, whatever it is sorted by.

### Fixed

**Backups were losing things quietly.** Followed subreddits, followed Substack
publications, saved searches' group membership and the per-account
hide-reposts and hide-replies settings were all missing from an export. Backups
carry them now. Older backups still import exactly as they did.

**Saved and liked posts** showed as neither until you had opened the Saved tab
once. Also: deleting one account no longer leaves the row beneath it in a
strange state; a tall screenshot beside ordinary photos no longer stretches the
whole post; and pulling to refresh one feed no longer discards every other
feed's cached posts.

### Faster

Startup no longer decodes a week of cached posts before drawing anything, and
no longer builds the video engine and every plugin for a reader who opens
neither. Images decode at the size they are drawn at. Scrolling stopped laying
out each post's text twice, and stopped rebuilding a whole post when you
bookmark it.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
