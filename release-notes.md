## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without an account of X's choosing, keep what you follow on your own device —
with the plugins, feeds and fixes below on top.

### What's new

**The homepage looks like X now.** Following, For you and Reddit are proper
tabs with the accent underline instead of a dropdown; the top bar keeps one
icon (the feed filters — refresh is the pull gesture, settings moved into the
drawer) and ends in a hairline so posts no longer dissolve into it while
scrolling. The drawer carries your groups the way X's carries Lists. Timeline
stamps are compact ("5 min." instead of "vor 5 Minuten"), the translate button
only appears on posts in another language, and the last loading spinner is now
the same post-shaped placeholders the rest of the app uses. Tapping a
timestamp to see the exact date also works on the first tap now.

**Audio keeps playing when you leave.** Read-aloud and Substack podcasts
continue past the app going to the background, with play/pause/stop on the
lock screen and in the notification shade.

**Substack grew its other half.** Podcast posts play their episode, comments
open under a post, the archive is searchable, and posts show their like and
comment counts. Video posts wear a play badge so they're recognisable before
opening.

**Reddit threads got their depth back.** v.redd.it videos play in the app's
own player instead of a dead link; comments sort (best/top/new/controversial/
old); a tap folds a comment and its replies into a count; and the "load more
comments" rows Reddit holds back are shown and openable instead of the thread
ending mid-air.

**Links wear your theme.** The post-text renderer was rewritten: mentions,
hashtags and links now take the theme accent instead of hardcoded blue, emoji
no longer shift tap targets off their word, and every tap handler is released
when its post leaves the list — a slow leak that grew with every scroll.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
