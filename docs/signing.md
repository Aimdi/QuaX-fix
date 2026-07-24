# Release signing (Aimdi / QuaX-gamma)

Android only allows an app update when the **new APK is signed with the same
certificate** as the installed one. Upstream [Teskann/QuaX](https://github.com/Teskann/QuaX)
uses a private release keystore. This fork does **not** have that key.

If GitHub Actions has no `SIGNING_KEY` secret, release workflows used to fall
back to the runner’s **debug.keystore**. That file is created fresh on every
ephemeral CI machine, so **every release was signed with a different key**.
Android then refuses in-place updates — you have to uninstall and reinstall
each time.

Release workflows (`release.yml`, `build-release.yml`) now **fail** until a
stable keystore is configured.

## One-time setup

### 1. Create a keystore (on your machine)

```bash
keytool -genkey -v \
  -keystore quax-gamma.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias quax-gamma \
  -storepass 'CHOOSE_A_STORE_PASSWORD' \
  -keypass 'CHOOSE_A_KEY_PASSWORD' \
  -dname 'CN=QuaX-gamma, OU=Aimdi, O=Aimdi, L=Unknown, ST=Unknown, C=US'
```

Back up `quax-gamma.jks` somewhere safe. Losing it means users must uninstall
to install future builds again.

### 2. Add GitHub Actions secrets

Repo → **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `SIGNING_KEY` | `base64 -w0 quax-gamma.jks` (single line) |
| `KEY_STORE_PASSWORD` | store password from step 1 |
| `KEY_PASSWORD` | key password from step 1 |
| `KEY_ALIAS` | `quax-gamma` (or whatever `-alias` you used) |

With the GitHub CLI:

```bash
base64 -w0 quax-gamma.jks | gh secret set SIGNING_KEY
gh secret set KEY_STORE_PASSWORD --body 'CHOOSE_A_STORE_PASSWORD'
gh secret set KEY_PASSWORD --body 'CHOOSE_A_KEY_PASSWORD'
gh secret set KEY_ALIAS --body 'quax-gamma'
```

### 3. Publish fingerprints (optional but useful)

```bash
keytool -list -v -keystore quax-gamma.jks -alias quax-gamma
```

Put the SHA-1 / SHA-256 into `release-notes.md` (and keep them in sync) so
users can verify downloads.

### 4. Cut a new release

After secrets are set, tag / dispatch a release as usual. The first install of
a properly signed build still requires uninstalling any previous
debug-signed Aimdi APK once. After that, Obtainium / sideload updates should
apply in place.

## What stays debug-signed

`ci.yml` may still produce **debug-signed** APK artifacts for PR testing.
Those are not for Obtainium or long-lived installs.
