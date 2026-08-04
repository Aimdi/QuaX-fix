# Threads direct session (optional)

Optional **read-only** mode for the existing Threads plugin that talks to Meta
directly — browser cookies on `www.threads.com` and/or an Instagram Bearer
(`IGT:2:…`) on `i.instagram.com`. Account risk is accepted by the reader;
prefer a disposable secondary account.

Approach inspired by public clients such as
[threads-go](https://github.com/teslashibe/threads-go) — **no code copied**.

## Why

RSSHub + Xy never touch Meta from the phone, but they need a self-hosted
proxy and cannot show a real Following feed. Guest GraphQL `doc_id`s rotate.
A pasted web session can:

| Credential | Host | What it unlocks |
|---|---|---|
| Cookies (`sessionid`, `csrftoken`, `ds_user_id`, `mid`, `ig_did`) | `www.threads.com` | Profile lookup, per-user threads |
| Bearer `IGT:2:…` (+ user id / device id) | `i.instagram.com` | Home / Following timeline |
| None | `www.threads.com` HTML | Guest SSR scrape of public profiles (iPhone Safari UA) |

## Auth UX

Settings section **Direct session** (above RSSHub):

1. Paste a `Cookie` header (or `name=value; …` string) exported from a logged-in
   Threads browser tab.
2. Optionally paste Bearer `IGT:2:…` for the Following feed.
3. **Test session** hits `current_user` (cookies) and/or a short timeline
   (Bearer).
4. Secrets stored under `*_token` keys / `secretPrefKeys` — never exported.

No in-app password / Bloks login. No like, follow, repost, or compose.

## Feed priority

1. Bearer configured → Following timeline
   (`GET /api/v1/feed/text_post_app_timeline/?pagination_source=text_post_feed_following`)
2. Else cookies → merge local follows via
   `GET /api/v1/text_feed/{id}/profile/`
3. Else RSSHub instance → existing JSON Feed path
4. Else local follows → guest SSR of `https://www.threads.com/@handle`
5. Else → not configured

## Throttle & risk

- ≥2s between private API calls; stop that credential set for 30 minutes on
  `429`, “Please wait…”, or `login_required` / `logout_reason: 8`.
- Sessions may die; accounts may be checkpointed. Documented in settings copy.

## MVP

- Cookie + Bearer paste, test, clear
- Following feed (Bearer) and/or merged follows (cookies / SSR / RSSHub)
- Profile lookup prefers cookies when set, else Xy
- Unit tests with `MockClient` fixtures (no live credentials)

## Not in MVP

- In-app login WebView
- Write actions
- GraphQL `doc_id` chasing as primary path
- Video carousel playback beyond image URLs already on cards
