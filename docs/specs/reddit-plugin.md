# Reddit plugin (in the spirit of Stealth)

Answer to *"Stealth looks awesome — can't you make it a plugin of XTA?"*
Two findings decided the approach, both worth knowing before more is built.

## 1. It cannot be a port. It has to be a reimplementation

| | Stealth | XTA |
|---|---|---|
| Language | Kotlin | Dart |
| UI | Android views | Flutter |
| Storage | Room | sqflite / prefs |
| Licence | **GPLv3** | **MIT** |

Nothing about a Kotlin Android app can be "plugged into" a Flutter app — there
is no shared UI, storage or networking layer, so the feature has to be written
again in Dart either way.

The licence makes that the *only* option rather than merely the practical one.
Copying or translating Stealth's source into XTA would make the combined work
GPLv3, relicensing this entire app. This plugin is therefore written against
Reddit's own documented API. Stealth's source was consulted only to learn *which*
API a modern account-free client has to use (its `OAuthInterceptor` answers
that), not for its implementation.

## 2. Reddit no longer serves anonymous JSON

Measured from this machine, every unauthenticated path is refused:

| Endpoint | Result |
|---|---|
| `www.reddit.com/r/<sub>/hot.json` | **403** |
| `old.reddit.com/r/<sub>/hot.json` | **403** (explicit "Blocked" page) |
| `api.reddit.com/r/<sub>/hot` | **403** |
| a public Redlib instance | **403** |

So "account-free" now means *app-only OAuth*: the `installed_client` grant,
which authenticates the app rather than a person and takes a client id the user
creates once at `reddit.com/prefs/apps`. No account, no login, and the device id
sent is Reddit's own `DO_NOT_TRACK_THIS_DEVICE`.

Some of those 403s are likely datacenter-IP blocking rather than a policy that
would hit a phone, but the token flow is required regardless.

## What is implemented

- `reddit_client.dart` — app-only token with caching and early expiry, subreddit
  listings (hot / new / top / rising) with Reddit's `after` cursor, defensive
  parsing, and each documented status mapped to an actionable error.
- `reddit_store.dart` — followed subreddits in prefs; a merged feed that loads
  one page per subreddit and interleaves by date, because Reddit paginates per
  listing and there is no cursor across several.
- `reddit_screen.dart` — the feed, adding and removing subreddits, the client id,
  and a post view with its own text plus links out.
- Registered like the Substack plugin, off by default.

## Not implemented

- **Comments.** The biggest remaining chunk: `/comments/{id}` returns a nested
  `Listing` of `t1` items with `more` stubs to expand, so it needs its own model,
  a flattening pass with depth, and a threaded renderer.
- Search, user profiles, subreddit browsing without following, saved posts,
  multiple profiles (Stealth's per-profile subscriptions), media galleries,
  awards, flairs.
- Sort selection in the UI (the client takes it; the screen always asks for hot).

## Unverified

Every request in the tests is mocked, and the live endpoints cannot be reached
from this environment, so the first real request happens on a device with a real
client id. If it turns out Reddit refuses the `installed_client` grant from
phones too, the fallback is a self-hosted Redlib instance as the transport, which
would replace `reddit_client.dart` and nothing else.
