# macOS: installing a self-signed Protea build and enabling notifications

Guide for users who received a Protea build signed with the internal
**"Protea Local Dev"** certificate (the interim setup until the company
Developer ID signing described in [macos-distribution.md](macos-distribution.md)
is in place).

Because the certificate is self-signed, macOS doesn't recognize the developer
and blocks the first launch — but once the app is approved and running, it is
signed with a *stable* identity, so notifications work normally and your
permission survives app updates.

> **Only follow these steps for builds you received from a trusted internal
> source** (the approval below tells macOS to skip its malware check for this
> app). If in doubt, verify the build first — see
> [Verifying the build](#optional-verifying-the-build).

## 1. Install

Copy `protea.app` from the zip/DMG into `/Applications` (or `~/Applications`).

## 2. Approve the first launch (Gatekeeper)

Double-click the app. macOS will refuse with a message like *"Apple could not
verify 'protea' is free of malware"*. Then:

1. Open **System Settings → Privacy & Security**, scroll down to the
   *Security* section.
2. You'll see *"protea" was blocked…* — click **Open Anyway** and confirm
   with your password / Touch ID.
3. Launch the app again; this time an *Open* button is offered.

This is needed **once per downloaded copy**, not on every start.

- On older systems (macOS 14 Sonoma and earlier) you can instead right-click
  the app → **Open** → **Open**.
- Terminal alternative (removes the quarantine flag so no dialog appears):

  ```sh
  xattr -d com.apple.quarantine /Applications/protea.app
  ```

## 3. Allow notifications

On first launch, macOS asks: *"protea" would like to send you notifications* —
click **Allow**.

If you dismissed or missed the prompt:

1. Open **System Settings → Notifications**.
2. Select **protea** in the app list.
3. Enable **Allow notifications** and pick the **Banners** or **Alerts** style.

That's it — new messages now notify while the app is running.

## Things to know

- **Notifications only arrive while Protea is running.** Closing the window
  quits the app entirely (it's not a menu-bar/background app), so keep it
  open — minimizing or hiding (⌘M / ⌘H) is fine.
- Protea doesn't notify for the room you currently have open while the window
  is focused — that's intentional, not a missing notification.
- **Focus / Do Not Disturb** suppresses banners like for any app. If
  notifications seem to stop, check the Focus status in the menu bar first.
- **Updates keep working.** As long as newer builds are signed with the same
  internal certificate, macOS treats them as the same app: no new Gatekeeper
  approval on updates of the same file (a freshly downloaded copy needs step 2
  again) and no new notification prompt.
- If you previously ran an unsigned developer build of Protea, its stale entry
  can linger in System Settings → Notifications. If notifications don't work
  even though everything is enabled, toggle *Allow notifications* off and on
  for protea, or remove the app from the list and relaunch it so it
  re-registers and prompts again.

## Optional: verifying the build

To check that the app really is the internally signed build and untampered:

```sh
codesign --verify --strict /Applications/protea.app && echo OK
codesign -d -r- /Applications/protea.app
```

The second command must print the signing requirement

```
designated => identifier "energy.vgt.protea" and certificate leaf = H"d776724f49ad5784a348fec7b17f9dedb942a720"
```

with exactly this hash — it identifies the internal "Protea Local Dev"
certificate. A different hash means the app was signed by someone else: don't
approve it, and check with the person who built it.

## Troubleshooting

- **No permission prompt ever appears and protea isn't listed under System
  Settings → Notifications:** make sure you launched the app at least once
  past the Gatekeeper approval, then relaunch it. The permission request runs
  on every start.
- **Everything is enabled but nothing shows:** confirm the app is still
  running (a closed window means a quit app), that no Focus mode is active,
  and that *Show previews* / notification style aren't set to nothing.
- **Still stuck:** run the app from Terminal
  (`/Applications/protea.app/Contents/MacOS/protea`) and watch the log — a
  line like `macOS notification permission not granted` confirms macOS is
  blocking it, in which case remove protea's entry in the Notifications
  settings and relaunch.
