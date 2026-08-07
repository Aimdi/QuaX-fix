## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without posting, keep what you follow on your own device — with the plugins and
fixes below on top. Nothing here adds compose, reply, quote, or like-on-X.

### Fixed

**The timeline no longer crashes on posts with an ALT badge.** The first post
carrying alt text replaced the whole feed with a stack trace ("Null check
operator used on a null value"); counting its lines now knows how big an inline
badge is.

**Pixiv sign-in works.** Requests carry the signed timestamp the official app
sends, so a valid token stops being refused as if it were wrong — and when
Pixiv does refuse one, the message now says Pixiv's actual reason instead of a
bare error.

**Adding an X account can no longer lose it.** Sign-in closed the app's shared
database mid-write; deleting an account now also signs its session out of x.com
(it used to linger in the webview's cookies) and asks before doing so.
Follow/unfollow no longer flickers back when the list reloads faster than the
write.

### What's new

**The Fediverse with nothing configured.** The Mastodon plugin now works out of
the box: an account's own instance is asked first (it has every post, wherever
they federate), then any instances you add — the settings screen takes several
now — then five large built-in ones. A dead or closed instance costs one failed
try, never the feature.

**Reddit, fetched once.** The tab, the home timeline and groups share one
source, so a subreddit followed in three places downloads once and
pull-to-refresh is what goes past the cache. Refusals are told apart — private,
banned, quarantined, behind a login, or simply empty — instead of all reading
as one error, and backing out of the Reddit login no longer strands you on a
blank page.

**Backups are complete.** Followed stocks, Threads, Bluesky and Mastodon
accounts and your device-local Reddit upvotes are all in the export now (the
upvotes exist nowhere else), the import preview lists them, and a test compares
the backup against the database schema so the next table cannot be forgotten
quietly.

**Sturdier everywhere else.** Substack posts can no longer run scripts in the
reader. Error screens scroll at large text sizes instead of pushing their own
Retry button off the screen. The first-run dialogs now tell the truth — the app
does try without an account, and accounts are picked by health, not randomly —
in all 29 languages. The APK sheds 17 MB of locale data nothing read, drops the
"all files access" permission nothing used, and the timeline cache stops
growing without bound.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
