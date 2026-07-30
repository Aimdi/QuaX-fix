## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without an account of X's choosing, keep what you follow on your own device —
with the plugins, feeds and fixes below on top.

### What's new

**Large feeds stop stampeding the API.** Following and group chunk searches
used to fire every chunk at once — with a thousand subscriptions that meant
dozens of concurrent searches, a cascade of 404s, and accounts getting flagged.
Chunks now run a few at a time, membership refreshes are debounced, and For You
app-bar refresh actually remounts the active tab instead of waiting for a tab
switch.

**You land where you left off.** Following and For You remember reading
position the same way groups already did — a caught-up divider and a restore
when you come back (Settings → Remember reading position).

**Fullscreen video lets you out again.** After off-screen player reclaim,
exiting fullscreen could strand you with dead controls. Fullscreen now owns its
own player surface so reclaim cannot dispose the exit path; scrolling still
reclaims tiles that leave the screen.

**Timeline parsers survive a bad entry.** One reshaped GraphQL node no longer
wipes a whole page — cursors and tweet builders skip junk instead of throwing.

**Reddit threads have their depth back**, with a proper v.redd.it player.
**Substack** picks up comments, podcast audio, and archive bits it was missing.
**Rich text** is typed and themed, and it lets go of its tap recognizers.

**The README matches the product** — Obtainium up front, plugins listed, X Look
instead of retired Fairy Forest / Pitch Black.

**Cold Cloud VMs can install again** — `cloud_install.sh` bootstraps FVM and
the Android SDK when a snapshot is missing.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
