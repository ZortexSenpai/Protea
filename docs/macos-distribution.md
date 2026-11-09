# macOS: registering Protea with the company Apple Developer account

How to move Protea from local development signing to proper company signing
(Developer ID) so it can be distributed to other users — Gatekeeper-clean and
with working notifications.

## Current state (local development)

The macOS Runner target is signed with **"Protea Local Dev"**, a self-signed
certificate in Sandro's login keychain. It exists because macOS ties
notification permission to the app's code signature; the Flutter-default
ad-hoc signing changes on every build, which silently breaks notifications.

This works for local development only:

- Other machines (including CI) can't build the macOS target until they either
  create a cert with the same name or switch the identity in
  `macos/Runner.xcodeproj`.
- Other users' Macs will refuse to launch such a build without digging through
  System Settings → Privacy & Security. If you do hand a self-signed build to
  someone in the meantime, point them at
  [macos-self-signed-install.md](macos-self-signed-install.md).

For distribution, Release builds must be signed with a **Developer ID
Application** certificate from the company account and **notarized** by Apple.

## 1. One-time: enroll the company

1. Go to <https://developer.apple.com/programs/enroll> and enroll as an
   **organization** (not individual), 99 USD/year.
   - You need the company's legal entity name and its **D-U-N-S number**
     (look it up / request at <https://developer.apple.com/enroll/duns-lookup>).
   - The person enrolling becomes the **Account Holder** and must have
     authority to sign agreements for the company.
2. After approval, note the **Team ID** (10 characters, shown under
   *Membership details* at <https://developer.apple.com/account>).
3. Add developers under *Users and Access* in App Store Connect. For signing
   day-to-day, the *Developer* role is enough; **only the Account Holder can
   create Developer ID certificates** (Admins can via the App Store Connect
   API / Xcode Cloud in some setups, but plan for the Account Holder to do
   step 2 below).

No App ID registration is required for Developer ID distribution — Protea
uses only unrestricted entitlements (sandbox, network, user-selected files,
microphone). Registering the bundle ID `energy.vgt.protea` only becomes
necessary for the Mac App Store or push notifications.

## 2. One-time: create the Developer ID certificate

As the Account Holder, on the Mac that will do release builds:

1. Xcode → Settings → Accounts → add the company Apple ID.
2. Select the team → *Manage Certificates…* → **+** → **Developer ID
   Application**.
3. Verify it landed in the keychain:

   ```sh
   security find-identity -v -p codesigning
   # expect: "Developer ID Application: <Company Name> (<TEAMID>)"
   ```

(Alternative without Xcode: create a CSR in Keychain Access and upload it at
developer.apple.com → Certificates, IDs & Profiles → Certificates → +.)

Export the certificate **with private key** (.p12) from Keychain Access and
store it in the company password manager — you'll want it for CI and for
future build machines. Losing it means revoking and re-issuing, which changes
nothing for users but is avoidable churn.

## 3. Point the Release build at the certificate

In `macos/Runner.xcodeproj/project.pbxproj`, the Runner target's **Release**
configuration currently has:

```
CODE_SIGN_IDENTITY = "Protea Local Dev";
CODE_SIGN_STYLE = Manual;
```

Change it to (keep Debug/Profile on "Protea Local Dev"):

```
CODE_SIGN_IDENTITY = "Developer ID Application";
CODE_SIGN_STYLE = Manual;
DEVELOPMENT_TEAM = <TEAMID>;
ENABLE_HARDENED_RUNTIME = YES;
OTHER_CODE_SIGN_FLAGS = "--timestamp";
```

Notes:

- `ENABLE_HARDENED_RUNTIME` and the secure `--timestamp` are **required for
  notarization**. Release builds are AOT-compiled, so the hardened runtime
  needs no JIT exceptions; the existing `Release.entitlements` already carries
  everything else (sandbox, network, files, audio-input).
- The same can be done in the Xcode UI: Runner target → Signing &
  Capabilities → Release → team + identity, and add the *Hardened Runtime*
  capability (Release configuration).
- Notification permission stays stable for users across updates as long as
  every release is signed by the same team — the signature's designated
  requirement is then team-based, not per-build.

## 4. Per release: build, notarize, staple

One-time setup for notarization credentials: create an **app-specific
password** for the Apple ID at <https://account.apple.com> (Sign-In and
Security → App-Specific Passwords), then store it in the keychain:

```sh
xcrun notarytool store-credentials protea-notary \
  --apple-id <apple-id@vgt.energy> --team-id <TEAMID> --password <app-specific-password>
```

Then for each release:

```sh
flutter build macos --release
APP=build/macos/Build/Products/Release/protea.app

# sanity-check the signature
codesign --verify --strict --deep "$APP"
codesign -dv "$APP" 2>&1 | grep Authority   # expect Developer ID Application

# submit for notarization (usually takes a few minutes)
ditto -c -k --keepParent "$APP" protea.zip
xcrun notarytool submit protea.zip --keychain-profile protea-notary --wait

# staple the ticket to the app, then package for distribution
xcrun stapler staple "$APP"
ditto -c -k --keepParent "$APP" protea-<version>.zip   # or wrap in a DMG
```

If `notarytool submit` reports `Invalid`, fetch the details with
`xcrun notarytool log <submission-id> --keychain-profile protea-notary`.

Final check — this must pass on the packaged app for Gatekeeper to accept it
on other Macs:

```sh
spctl --assess --type exec -vv "$APP"
# expect: accepted, source=Notarized Developer ID
```

## Mac App Store (optional, later)

If Protea should ship via the App Store instead of direct download: register
the bundle ID `energy.vgt.protea` under *Certificates, IDs & Profiles*, create
the app in App Store Connect, and sign with *Apple Distribution* + a Mac App
Store provisioning profile (Xcode's archive/upload flow handles this). The app
is already sandboxed, which is the main App Store requirement. Notarization is
not needed for App Store builds.
