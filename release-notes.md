## XTA

A read-only fork of [QuaX](https://github.com/Teskann/QuaX). Same idea — read X
without posting, keep what you follow on your own device — with the plugins and
fixes below on top. Nothing here adds compose, reply, quote, or like-on-X.

### Importing a Bluesky following list actually works

**A handle it could not read now says so.** The field asks for a handle and
shows an `@` in front of it, which invites a bare name — and a bare name is
exactly what Bluesky handles may not be. Typing one made the button do nothing
at all, with no message, however many times it was pressed.

**And the import no longer leaves you with an empty feed.** There is no
following feed to ask the public Bluesky server for, so a timeline is one
request per account you follow. Fine when you added a few by hand; hopeless the
moment several hundred arrived at once — the server rate-limits, and what comes
back is nothing. Reading is now spread over a few refreshes, whatever was read
already is kept, and the tab says how many accounts are still to come.

### A thread no longer swallows the rest of the timeline

**A thread in the feed used to draw its badge and then nothing** — no post, and
no post below it for the rest of the timeline. The line that connects a thread's
posts was sizing the card, and in a list it wanted to be infinitely tall, so
everything after it was laid out past the bottom of the screen.

That is also why **Expand on a row of reposts could empty the feed**: expanding
draws full posts, and one thread among them was enough. Replies on an opened
post had the same fault.

### Adding accounts from anywhere to a group

**One box now reads whatever you type.** A subreddit, a Threads or Bluesky
handle, a Fediverse address, a newsletter, or a link pasted from any of them —
it offers what the text could be and follows the one you pick, without leaving
the group. **Fediverse accounts can join a group** the way Bluesky ones already
could, and their posts mix into that group's feed.

**The subscriptions list stops pretending.** Everything that was not an X
account was drawn as a saved search: a followed subreddit wore a search icon,
claimed to be a search term, and opened X's search for its own name. Each row
now carries its own network's mark and leads back to that network — and
unsubscribing from one actually removes it.

### Smaller things

A group made only of subreddits, newsletters or plugin accounts **scrolls** now,
instead of stopping at one screen with the rest laid out where you could not
reach it. Repost cards **show their text rather than the entities X escapes it
with**, so a post reading `>,,<` no longer arrives as `&gt;,,&lt;`. And repost
grouping can be **switched off outright** under Settings › Posts, if you would
rather never collapse them.

---

First download? Install it with Obtainium 👇

[Add to Obtainium](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Aimdi/XTA)

XTA has its own application id (`com.aimdi.xta`), so it installs alongside
upstream QuaX and alongside earlier builds of this fork rather than over them.
Nothing carries across from an older install — export a backup first if you want
your subscriptions, groups and saved posts.
