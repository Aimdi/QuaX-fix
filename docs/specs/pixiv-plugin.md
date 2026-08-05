# Pixiv plugin (private)

Read-only browsing of a Pixiv following feed. Inspired by the *approach* of
[pixez-flutter](https://github.com/Notsfsssf/pixez-flutter) (GPL-3.0) and
[Pixiv-MultiPlatform](https://github.com/magic-cucumber/Pixiv-MultiPlatform) —
**none of their code is copied or translated**. Auth and `app-api.pixiv.net`
calls are written fresh in Dart against the well-known unofficial API shape.

## Private

- Listed in `plugins.json` as `{ "id": "pixiv", "available": false }` so the
  public catalogue does not offer it.
- `XtaPlugin.isPrivate == true`; the store only shows it when “Show private
  plugins” is on, or once already installed.

## Auth

Pixiv no longer accepts password login on the app API. The reader pastes a
**refresh token** (obtained outside the app — browser OAuth / sniffing tools
documented by the Pixiv community). The plugin exchanges it for a short-lived
access token via `https://oauth.secure.pixiv.net/auth/token`.

No compose, bookmark, follow, or like write-backs to Pixiv.

## MVP

| Feature | Detail |
|---|---|
| Settings | Refresh token (secret), show R-18 toggle (off by default), test connection |
| Home tab | Following timeline (`GET /v2/illust/follow`) |
| Cards | Title, author, thumbnail (Referer required), open `pixiv.net/artworks/{id}` |
| Profile | User detail + their illusts by numeric id |

## Not in MVP

- In-app OAuth WebView / PKCE login UI
- Ugoira playback, manga reader, novel API
- Search, ranking, comments, local download manager
- Bookmark / follow / like on Pixiv
