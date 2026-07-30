## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without an account of X's choosing, keep what you follow on your own device —
with the plugins, feeds and fixes below on top.

### What's new

**The app is XTA now.** New name, new icon label, new application id
(`com.aimdi.xta`). Android therefore treats it as a different app: it installs
**alongside** your existing QuaX-fix, and nothing carries across on its own —
**export a backup from the old install first**, import it here, then uninstall
the old one when you are satisfied.

**Scrolling past videos stopped costing.** Three leaks went together: a GIF
scrolled past kept decoding forever; a video that left the screen kept its
decoder, its demuxer and its cache; and a fast fling allocated a player for
every tile it swept over. Now GIFs pause off screen and resume on the way back,
a tile off screen for a few seconds hands its player back (scrolling back
re-attaches at the same position), and a fling costs nothing — only the video
you stop at is built. There is also a new experiment in Settings → Media:
**Direct hardware decoding** skips a per-frame copy so scrolling stays smoother
while a video plays; on some devices video renders black — turn it back off if
yours is one.

**Immich.** A new plugin: tell a bookmark folder to send its posts' photos and
videos to your own Immich server. Configured with a server address and API key
(with a connection test), an album per folder if you want one, videos optional.
Filing a post uploads its media once — re-filing it later does not re-send.

**Reddit shows the files now.** Galleries render every picture with an n/N
badge instead of a bare link. A post opened from search shows its image — the
search page never carried it, so the post's own page is read instead. Video and
article posts show Reddit's full-width preview with a play badge, not a 70px
thumbnail smear.

**The image-quality setting reaches the photo viewer.** A shadowed variable had
kept it from ever applying there, so viewer photos loaded at X's default size
regardless of the setting.

**Sixteen navigate-at-the-wrong-moment crashes removed**, found by turning the
compiler check for them into a hard build error so the class cannot return.

**The media filter menu got its icons** — All / Photos / Videos each lead with
their symbol, like X's own.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
