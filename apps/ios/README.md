# Lift Log for iPhone

A small SwiftUI app that shows `liftlog.html` (bundled from the repo root) in a
web view, plus native help the web page can't get on an iPhone. The page talks
to it through `window.webkit.messageHandlers.liftlog`:

| Message | What the app does |
|---|---|
| `{type: "haptic"}` | Vibrates when the rest is over. |
| `{type: "awake", on}` | Keeps the screen on during a workout. |
| `{type: "share", name, text}` | Opens the share sheet with the backup file. |
| `{type: "claude", id, tier, messages}` | Asks Claude (Messages API, streamed) and answers through `window.__liftlogClaude(id, event)`. |
| `{type: "claudeCancel", id}` | Stops that answer. |
| `{type: "claudeKey", key}` | Checks the Anthropic API key and saves it in the Keychain (empty removes it), answers through `window.__liftlogClaudeKey`. |

In the app, the page runs in local mode: data lives in the web view's
localStorage (origin `liftlog://app`). Move data in with Settings → Your data → Restore.

Claude (the Coach tab, the questionnaire) runs through the app on the person's
own Anthropic API key, added under Settings → Claude. `Claude.swift` keeps the
key in the Keychain (the page never sees it) and calls the Messages API
directly: Claude Opus 5.5 for coaching, Claude Haiku 5.5 for short reads.
Usage is billed to that Anthropic account. `window.liftlogApp.claudeKey` tells
the page at load whether a key is saved.

## Building without a Mac
- `project.yml` is an XcodeGen spec. The `.xcodeproj` is generated
  (`xcodegen generate`) and not checked in. Swift files go in `LiftLog/`;
  settings and Info.plist keys go in `project.yml`.
- `.github/workflows/ios.yml` (copied from orthotics-platform, which explains
  the re-signing for the "ö" in the account name) builds on a GitHub macOS
  runner for every push that changes `apps/ios` or `liftlog.html`, or by hand
  (Actions → iOS app → Run workflow). Build number = run number.
- Bundle ID `de.niklasapps.liftlog`. It needs an App ID in the developer portal
  and an app record in App Store Connect before the first upload.
- App icon: `LiftLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png`, drawn by
  `make_icon.py` (opaque, full bleed).

## Secrets (repository settings → Secrets and variables → Actions)
The same values as orthotics-platform. GitHub never shows a secret's value, so set
them again from the files (PowerShell, from this repo):

```powershell
$dir = "$HOME\Documents\Business\Tracery\App Dev"
Get-Content -Raw "$dir\AuthKey_K962X6376P.p8" | gh secret set ASC_KEY_P8 -R NiklasApps/lift-log
gh secret set ASC_KEY_ID -R NiklasApps/lift-log -b K962X6376P
gh secret set DIST_CERT_P12 -R NiklasApps/lift-log -b ([Convert]::ToBase64String([IO.File]::ReadAllBytes("$dir\OrthoScan-distribution.p12")))
gh secret set DIST_CERT_PASSWORD -R NiklasApps/lift-log -b (Get-Content "$dir\OrthoScan-distribution.password.txt" -TotalCount 1)
gh secret set ASC_ISSUER_ID -R NiklasApps/lift-log
gh secret set APPLE_TEAM_ID -R NiklasApps/lift-log
```

The `.p12` and its password are the backup that orthotics-platform's
`make_signing_certificate.py` wrote next to the `.p8` file. Use `-b` for the
password: piping it would add a line break that breaks the certificate import.
The last two ask for the value: the Issuer ID is at the top of App Store Connect
→ Users and Access → Integrations → App Store Connect API, the Team ID under
developer.apple.com → Account → Membership details. Without these
secrets, the workflow builds an unsigned `LiftLog.ipa` as an artifact.
