## QuaX-fix

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without an account of X's choosing, keep what you follow on your own device —
with the plugins, feeds and fixes below on top.

### What's new

**Stocks.** A tab of its own, off until you install it. A reel of price cards
across the top, then each symbol at the size a market page gives it: the price
large, the day's move beside it, the line drawn against the previous close, and
the volume and the year's high and low underneath. Tickers are a subscription
like any other, so they can join a group.

**The ticker chart, readable.** Both axes are labelled, and dragging across the
chart reports the price under your finger instead of only the latest one.
Cashtags that are spoken one way and quoted another — `$SPX`, `$DAX`, `$BTC` —
now find their symbol instead of charting as "no data".

**Plugins are published, not just shipped.** The plugin store reads its list
from `plugins.json` in this repository, so a plugin can be added or withdrawn
without a new APK. Uninstalling one now deletes what it saved: its
subscriptions, the group entries pointing at them, its cache on disk and its
settings — including the Reddit sign-in and the Deepmarks signing key. Each
installed plugin says what it is currently holding.

**Substack.** A paid post that gives away its opening now shows that opening,
with a note where the free part ends, instead of a lock over an article you were
sent. Reading aloud lets you pick the engine and the voice, so an installed
speech engine of your own is actually used.

**Reddit.** The feed carries the same bar wherever it appears — sort, search,
add a subreddit, manage them — rather than only in its own tab.

**Links open inside the app** by default, instead of handing you to a browser.

**Reading aloud keeps going when you close the article.** It used to stop
mid-sentence the moment you left the tab. While something is being read, a bar
under every screen says what it is and stops it on a tap, so the control is
wherever you are rather than back in the article you left. Leaving the app
itself is not covered — there is no media notification behind this yet, so
Android may reclaim the process.

**Subreddits in a group actually show their posts.** A group with a subreddit
in it asked for its posts once, before the group knew its own members, and
never asked again — so it sat there empty. Substack publications in a group had
the same fault and are fixed with it.

**Read several groups at once.** Hold a group in the switcher and it is read
alongside the one you are in; hold it again and it is not. Nothing is written
down — the combination lives for as long as you are using it.

**A post's pictures are laid out along a row**, all at one height and each as
wide as its own shape, instead of one at a time behind a swipe. That is why the
number you can see changes from post to post: tall photos are narrow and three
fit, wide ones are broad and barely two do.

**Choose which browser links open in.** Settings → General lists every browser
on the phone, so links from a feed can go somewhere other than the system
default without changing that default for everything.

**Tabs change from the bottom bar and nowhere else.** A drag anywhere in a page
used to change them, so every sideways gesture in the app — a media carousel, a
nested tab view — was competing with the pager for the same finger.

**Groups read together wear their own colours** in the switcher, rather than one
shared highlight, so which of them are combined is visible at a glance.

**Videos stop reading a film's worth ahead.** libmpv's defaults are built for
sitting down to one film, not for scrolling past twenty clips, and nothing was
capping them unless a prefetch had been set by hand.

**A new app icon.**

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/QuaX-fix)

This fork is signed with its own key, so Android will not update an install of
upstream QuaX in place — and upstream will not update this one. Pick one.
