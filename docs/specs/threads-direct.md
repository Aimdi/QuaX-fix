# Threads direct session (optional)

Optional **read-only** mode for the existing Threads plugin that talks to Meta
directly — browser cookies on `www.threads.com` and/or an Instagram Bearer
(`IGT:2:…`) on `i.instagram.com`. Account risk is accepted by the reader;
prefer a disposable secondary account.

Approach inspired by public clients such as
[threads-go](https://github.com/teslashibe/threads-go) — **no code copied**.

## Why

RSSHub + Xy never touch Meta from the phone, but they need a self-hosted
proxy and cannot show a real Following feed. A pasted web session can:

| Credential | Host | What it unlocks |
|---|---|---|
| Cookies (`sessionid`, `csrftoken`, `ds_user_id`, `mid`, `ig_did`) | `www.threads.com` | Profile lookup, per-user threads |
| Bearer `IGT:2:…` (+ user id / device id) | `i.instagram.com` | Home / Following timeline (when no local Accounts) |
| None | `www.threads.com` | Guest GraphQL profile threads + SSR fallback |

## Auth UX

Settings section **Direct session** (above RSSHub):

1. Paste a `Cookie` header (or `name=value; …` string) exported from a logged-in
   Threads browser tab.
2. Optionally paste Bearer `IGT:2:…` for the Following feed when Accounts is empty.
3. **Test session** hits `current_user` (cookies) and/or a short timeline
   (Bearer).
4. Secrets stored under `*_token` keys / `secretPrefKeys` — never exported.

No in-app password / Bloks login. No like, follow, repost, or compose.

## Feed priority

1. Local Accounts non-empty → merge those handles via:
   - cookies → `GET /api/v1/text_feed/{id}/profile/` (on failure/empty → guest)
   - else RSSHub instance → JSON Feed
   - else guest: profile HTML → LSD + user id →
     `POST /api/graphql` `BarcelonaProfileThreadsTabQuery`
     (`doc_id` in `threadsGuestProfileThreadsDocId`), SSR `thread_items` fallback
2. Else Bearer configured → Meta home/For You
   (`GET i.instagram.com/api/v1/feed/text_post_app_timeline/` with
   `feed_type=for_you`, `reason=cold_start_fetch`, `client_session_id`, …)
3. Else cookies/RSSHub with no Accounts → empty list (add handles in the tab)
4. Else → not configured

Cookie/Bearer `login_required` still parks *session* calls for 30 minutes.
Guest GraphQL/SSR ignores that cooldown so Accounts keep loading.

## Throttle & risk

- ≥2s between private API calls; stop that credential set for 30 minutes on
  `429`, “Please wait…”, or `login_required` / `logout_reason: 8`.
- Sessions may die; accounts may be checkpointed. Documented in settings copy.
- Guest GraphQL `doc_id`s can rotate; SSR remains the fallback.

## MVP

- Cookie + Bearer paste, test, clear
- Following feed (Bearer, no Accounts) and/or merged follows (cookies / guest GraphQL / SSR / RSSHub)
- Profile lookup prefers cookies when set, else Xy
- Unit tests with `MockClient` fixtures (no live credentials)

## Not in MVP

- In-app login WebView
- Write actions
- Video carousel playback beyond image URLs already on cards
