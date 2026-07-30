## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without an account of X's choosing, keep what you follow on your own device —
with the plugins, feeds and fixes below on top.

### What's new

**Scrolling got cheaper, measurably.** A performance audit of the timeline
found and fixed a stack of quiet costs: every post's text was laid out twice
per frame and carried text-selection machinery it never used; the whole list
rebuilt twice on every page load; a settings write rebuilt every visible post;
saved/liked checks scanned your full lists per post per frame; video posters
and small logos decoded at their served size rather than their shown size; and
the weekly cache cleanup scanned a week of feed JSON before the first frame,
twice. Also fixed on the way: a recycled post tile could briefly show the
previous post's text after a refresh.

**Upvote Reddit posts — on your device.** The arrow in a Reddit post's footer
is now a button, in the same spirit as the X likes: nothing is sent to Reddit,
no account is involved, the arrow just remembers what you thought and the
score counts your vote. Removing the plugin forgets the votes.

**The profile media tab loads.** Two faults: a first page that carried only a
"next page" marker — common on sensitive profiles — was shown as "no tweets",
and long text-heavy profiles had their media grid cut short by a guard meant
for filtered feeds. The grid now follows the feed to where the media actually
is.

**Fewer stalls opening group feeds.** Subreddits and Substack publications in
a group fetch together instead of one after another, and the endpoint registry
stops re-downloading itself on every launch.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
