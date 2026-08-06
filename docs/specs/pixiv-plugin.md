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

Pixiv no longer accepts password login on the app API. XTA supports the same
**browser OAuth (PKCE)** flow community clients like Pixez use:

1. Generate `code_verifier` (random URL-safe string) and `code_challenge` =
   base64url(SHA-256(verifier)) without padding.
2. Open `https://app-api.pixiv.net/web/v1/login?code_challenge=…&code_challenge_method=S256&client=pixiv-android`
   in a WebView — the reader enters username, password, and 2FA on Pixiv’s form.
3. Intercept redirect to
   `https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback?code=…` or
   `pixiv://account?code=…`.
4. POST `https://oauth.secure.pixiv.net/auth/token` with
   `grant_type=authorization_code`, the code, verifier, redirect URI, and the
   public Android app client id/secret.
5. Persist `refresh_token` (and short-lived `access_token`) in preferences.

**Advanced fallback:** paste a refresh token manually in settings (same storage).

Constants and implementation: `lib/plugins/pixiv/pixiv_auth.dart`,
`lib/plugins/pixiv/pixiv_login_webview.dart`.

No compose, bookmark, follow, or like write-backs to Pixiv.

## MVP

| Feature | Detail |
|---|---|
| Settings | Sign in with Pixiv (WebView PKCE), sign out, advanced refresh-token paste, show R-18 toggle (off by default), test connection |
| Home tab | Following timeline (`GET /v2/illust/follow`) |
| Cards | Title, author, thumbnail (Referer required), open `pixiv.net/artworks/{id}` |
| Profile | User detail + their illusts by numeric id |

## Not in MVP

- Ugoira playback, manga reader, novel API
- Search, ranking, comments, local download manager
- Bookmark / follow / like on Pixiv
