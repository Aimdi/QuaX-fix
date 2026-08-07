## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without posting, keep what you follow on your own device — with the plugins and
fixes below on top. Nothing here adds compose, reply, quote, or like-on-X.

### X replies that actually show up

**Status screens keep offering more replies** when TweetDetail returns a thin
first page. Show-more cursors nested in conversation modules are parsed, the
thread cache remembers them, and a clear retry path replaces the old empty
silence under a non-zero reply count.

### Quotes you can expand

**“Show more” on a quoted post expands the text** instead of opening the quote.
The quotes footer always stays tappable, and the quotes list no longer folds
results into a single misleading thread.

### Bluesky threads in the app

**Open posts as in-app threads** with ancestors and replies. Cards show counts,
reposts, quotes, and link cards. People search finds accounts; profiles page
further with the author-feed cursor. Still public AppView only — no Bluesky
login, no writes.

### Threads closer to the app

**Repost chrome, verified badges, linkified captions**, always-on engagement
icons (local likes stay on device), a Following-strip add control, and a clearer
thread screen with indented replies.

### Faster Pixiv gallery

**Decode caps, better thumbs, soft refresh, earlier paging**, parallel detail
loads, and keep-alive tabs so Ranking and Bookmarks keep scroll position and
warm images — Pixez-oriented speed without copying Pixez.

### Mastodon replies without search

**Reply threads load even when public search resolve is blocked** (401). The
client uses the status id in the URL, then rediscovers via open instances when
needed.

### Plugin store categories that scale

**Social, Communities, Newsletters, Art, Markets, Bookmarks, Media** replace the
old catch-all Reading bucket so ten built-ins are easier to scan.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
