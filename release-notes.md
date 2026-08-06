## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without an account of X's choosing, keep what you follow on your own device —
with the plugins, feeds and fixes below on top.

### What's new

**Your feed, your rules.** Quiet accounts (cap how many posts someone can dump
into a load), language hide/fold filters, and muted keywords that can expire or
fold instead of vanish. Antennas listen for keywords and open as their own
feeds. Subscription packs export and import a group of follows as one file.
Profile notes stay private on your device; clip notes on saved posts are
searchable. A multi-column Deck pins groups side by side. Calm mode hides
engagement counts without zen's other caps. Long-press a hashtag to follow it
as a topic search.

**Reading that stays calm.** Status threads draw a connector from avatar to
avatar and stop indenting after two levels with “Continue thread”. Consecutive
reposts collapse into one horizontal row. Interleaved Reddit/Substack cards
carry a thin brand-colour strip so mixed feeds show where each post came from.
Sensitive media can be remembered (“always show”) instead of asking every time.
Groups show their mark, colour and member count in the feed header. Scroll
restore and caught-up position keep your place when you leave and come back.

**Alt text you can actually read.** When X sends it, media shows an ALT badge;
long-press to read the description.

### Fixed

Caught-up restore on group feeds no longer races the database read of your last
position. Migration 49 ALTER columns tolerate partial test fixtures so upgrades
do not fail mid-way.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
