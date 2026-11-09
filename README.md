# Protea

A cross-platform [Matrix](https://matrix.org) chat client built with Flutter.
One codebase, native builds for **Windows, macOS, Linux, iOS and Android**.

Built on the [matrix](https://pub.dev/packages/matrix) Dart SDK (the same SDK
that powers FluffyChat), with a SQLite store so your session and room cache
survive restarts, and [vodozemac](https://github.com/matrix-org/vodozemac) for
end-to-end encryption.

## Features

**Accounts & login**
- Sign in to any Matrix homeserver (password login)
- Single sign-on (SSO / OIDC), including per-provider buttons on homeservers
  with multiple identity providers (MSC2858)
- Multiple accounts with a quick account switcher; session persistence
- Presence with manual status (online / away / invisible + status message)
  and automatic away after 10 minutes of inactivity

**Messaging**
- Full timeline with infinite scroll-back, date and unread dividers
- Formatted messages: markdown input, HTML rendering with mention pills,
  spoilers and syntax-highlighted code blocks
- Media: images with viewer and captions, inline video playback, file
  attachments, voice messages with waveforms, inline PDF and text-file
  previews
- Emoji picker, custom emotes and sticker packs (MSC2545 image packs,
  interoperable with FluffyChat, Cinny and Nheko), GIF search (Klipy,
  bring your own key)
- Replies, edits, reactions, forwarding, threads, deletion and pinned messages
- Polls (create, vote, live results, end)
- Message search — within a room or across all rooms (server-side, so
  encrypted rooms are not included) — per-room drafts, typing indicators
  and read receipts
- Drag-and-drop file upload and clipboard image paste
- Slash commands (`/me`, `/shrug`, `/spoiler`, `/invite`, `/op`, … — type `/`
  for the full palette)

**End-to-end encryption**
- E2EE on by default via vodozemac, with cross-signing, SSSS and online key
  backup (guided recovery-key setup on first login)
- Interactive device verification with emoji comparison (SAS) and a
  scannable QR code (show-side), including requests from other clients
  like Element
- Security settings: backup status, device list with per-device verification

**Rooms & spaces**
- Discord-style spaces rail with drag-to-reorder, unread and mention badges
- Custom channel groups with manual ordering (synced via account data)
- Space lobby showing the full room hierarchy, join and knock support
- Public room directory search, room creation, DMs with user search
- Room settings: avatar/banner, topic, aliases, join rules, history
  visibility, per-room notification level, encryption toggle, room upgrade
- Member list with presence grouping, roles and moderation actions
  (kick / ban / power levels), pinned (favourite) rooms
- Quick switcher (Ctrl/Cmd+T) to jump to any room, DM or person

**Interface**
- Four layouts: Discord-style workspace, frosted-glass "liquid" variant,
  two-pane split, and a classic flat list — all responsive
- Theme families: Material (9 accent colors), Catppuccin, Nord, Dracula,
  Gruvbox, Tokyo Night; light/dark/system; four font sizes
- Localized in English, German, Spanish, French and Italian
- Local desktop notifications (see [Notifications](#notifications))

## Getting started

Requires:

- the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.35 or
  newer) on your `PATH`
- a [Rust toolchain](https://rustup.rs) — needed at build time to compile the
  vodozemac encryption bindings

```sh
flutter pub get
flutter run          # runs on the connected device / current desktop OS
```

### Platform notes

| Platform | Requirements |
|----------|--------------|
| Linux    | `clang`, `cmake`, `ninja-build`, `gtk3-devel`, appindicator and libmpv headers (Fedora: `sudo dnf install clang cmake ninja-build gtk3-devel libayatana-appindicator-gtk3-devel mpv-libs-devel`; Debian/Ubuntu: `libayatana-appindicator3-dev libmpv-dev`) |
| Windows  | Visual Studio 2022 with the “Desktop development with C++” workload |
| macOS    | Xcode (network client entitlement is already configured). Notifications require Apple-issued code signing — see [Notifications](#notifications). |
| iOS      | Xcode + an Apple developer account for device deployment |
| Android  | Android Studio / Android SDK (INTERNET permission is already configured) |

Build release artifacts with `flutter build <linux|windows|macos|ipa|apk>`.

### Installing on Linux

`install-linux.sh` copies the app into place and registers a launcher
(desktop entry, icon and a `protea` command). Running it again updates an
existing installation; chat data is never touched. Video playback needs
libmpv at runtime (Fedora: `mpv-libs`, Debian/Ubuntu: `libmpv2`); the
Flatpak bundles it.

```sh
flutter build linux --release
./install-linux.sh              # per-user install to ~/.local/opt (no sudo)
sudo ./install-linux.sh         # system-wide install to /opt
./install-linux.sh --uninstall  # remove either install again (keeps chat data)
```

Or build and install in one step:

```sh
tool/build-install-linux.sh             # build, then install for the current user
tool/build-install-linux.sh --system    # build, then install system-wide (asks for sudo)
tool/build-install-linux.sh --no-build  # install an already-built bundle
```

To build a distributable zip (the installer plus the application folder —
users extract it and run `./install-linux.sh`):

```sh
tool/package-linux.sh           # builds, then creates dist/protea-<version>-linux-<arch>.zip
tool/package-linux.sh --no-build   # package an already-built bundle
```

### Flatpak

To build a Flatpak instead (manifest and desktop/AppStream files live in
`flatpak/`), install `flatpak-builder` (Fedora: `sudo dnf install
flatpak-builder`, or `flatpak install flathub org.flatpak.Builder`) and run:

```sh
tool/build-flatpak.sh           # builds, then creates dist/protea-<version>-linux-<arch>.flatpak
tool/build-flatpak.sh --install   # …and installs it for the current user
```

The Flutter bundle is compiled outside the sandbox and packaged with the
freedesktop 24.08 runtime; users install the resulting file with
`flatpak install dist/protea-<version>-linux-<arch>.flatpak` and run it with
`flatpak run energy.vgt.protea`. Note that the sandboxed app keeps its chat
data in `~/.var/app/energy.vgt.protea/` — a Flatpak install does not see data
from a native install.

### Installing on Windows

`install-windows.ps1` copies the app into place and registers a launcher
(Start Menu shortcut, `protea` on `PATH` and an entry in Settings > Apps).
Running it again updates an existing installation; chat data in
`%APPDATA%\energy.vgt\protea` is never touched.

```powershell
flutter build windows --release
.\install-windows.ps1                    # per-user install to %LOCALAPPDATA%\Programs
.\install-windows.ps1 -AllUsers          # system-wide install to %ProgramFiles% (elevated)
.\install-windows.ps1 -DesktopShortcut   # …and put a shortcut on the desktop
.\install-windows.ps1 -Uninstall         # remove either install again (keeps chat data)
```

To build a distributable zip (the installer plus the application folder —
users extract it and run `install-windows.ps1`):

```powershell
tool\package-windows.ps1            # builds, then creates dist\protea-<version>-windows-<arch>.zip
tool\package-windows.ps1 -NoBuild   # package an already-built bundle
```

Windows blocks scripts that came from the internet; users who downloaded the
zip may need `Unblock-File .\install-windows.ps1` or
`powershell -ExecutionPolicy Bypass -File .\install-windows.ps1` once.

### Installing on macOS

The `protea-macos` artifact built by the GitHub Actions pipeline is ad-hoc
signed (the runner has no certificate) and not notarized, so Gatekeeper
refuses to open it after download ("damaged" / "cannot verify" dialog).
Strip the quarantine flag once after unzipping, then it runs normally:

```sh
xattr -dr com.apple.quarantine protea.app
mv protea.app /Applications/
```

Local builds are signed with the self-signed "Protea Local Dev" identity
(committed in the Xcode project; the CI workflow rewrites it to ad-hoc at
build time, so the local settings never break the pipeline). A machine
without that certificate in its keychain must either create one under that
name or build with `CODE_SIGN_IDENTITY=-`.

## Versions, releases and updates

**Settings > About** shows the running version, build number and commit
(copyable for bug reports) and has **Check for updates**. Desktop builds also
check GitHub once a day in the background (can be switched off) and announce
a new version with a notice. Turning on **Include beta versions** also offers
pre-releases.

How an update is installed depends on how Protea was installed:

| Installed with | Update |
|----------------|--------|
| `install-linux.sh` (per user) / `install-windows.ps1` | **Install and restart**: downloads the release zip, checks it against GitHub's SHA-256, quits, runs the bundled installer and starts the new version |
| `sudo install-linux.sh` / `install-windows.ps1 -AllUsers` | the same, with a pkexec / UAC prompt for the installer |
| Flatpak, macOS, a source build, anything else | **Download** button for the release file, installed by hand |

Chat data is never touched (it's the same installer that's run by hand). The
outcome is reported on the next start; if the install failed, the old version
starts again and the log's path is shown.

### Releases

`.github/workflows/release.yml` builds Linux, Windows and macOS packages and
publishes them as a GitHub release — after `flutter analyze` and the tests
pass — whenever you push:

| Push | Release | Example |
|------|---------|---------|
| to `main` | stable, offered to everyone | `v1.2.1` |
| to `development` | pre-release, offered only with "Include beta versions" (the 10 newest are kept) | `v1.2.1-dev.57` |
| a `v*` tag | exactly that version | `v2.0.0`, `v2.0.0-rc.1` |

Versions count up by themselves (`tool/release-version.sh`), following the
[Conventional Commits](https://www.conventionalcommits.org) since the last
stable release:

| Commits since the last release include | Bump | Example |
|---|---|---|
| `feat!: …`, `fix(api)!: …` or a `BREAKING CHANGE:` footer | major | 1.4.2 → 2.0.0 |
| `feat: …` / `feat(scope): …` | minor | 1.4.2 → 1.5.0 |
| anything else (`fix:`, `chore:`, non-conventional messages) | patch | 1.4.2 → 1.4.3 |

`version:` in `pubspec.yaml` is the floor: when it's higher than that, it's
released as is (and it's the first release when there are no tags yet).
Development builds are named after the version main would release next, so
beta users move back to stable once it's out. The
workflow run number is the build number; pushes that only touch Markdown or
`docs/` don't release.

Local builds made with the `tool/` scripts carry their commit and report
`pubspec.yaml`'s version; set `PROTEA_VERSION` / `PROTEA_BUILD_NUMBER` to stamp
one explicitly (see `tool/flutter-version-args.sh`).

## How SSO login works

The login page fetches the homeserver's supported login flows as you type and
shows an SSO button when `m.login.sso` is offered (one button per identity
provider if the server lists several). Tapping it opens the system browser on
the homeserver's `/login/sso/redirect` endpoint; the redirect back is caught

- on **Windows, macOS and Linux** by a temporary `localhost` HTTP server
  (`lib/src/sso.dart`), and
- on **Android and iOS** by the `protea://login` deep link (registered in
  `AndroidManifest.xml` and `Info.plist`, received via `app_links`).

The returned `loginToken` is then exchanged for an access token with
`m.login.token`. No webview is embedded — authentication happens in the
user's real browser, so existing IdP sessions and password managers work.

## End-to-end encryption

E2EE is fully wired in: `buildMatrixClient()` (`lib/src/matrix.dart`)
initializes vodozemac before the client starts, so encrypted rooms work out
of the box.

- On first login a guided setup (`widgets/bootstrap_dialog.dart`) creates
  cross-signing keys, SSSS and online key backup, and shows a recovery key to
  save. On later logins the same dialog unlocks the backup with that key and
  self-signs the new session.
- Sessions can also be verified interactively with emoji comparison
  (`widgets/key_verification_dialog.dart`), including verification requests
  coming from other clients. QR-code verification is not supported yet.
- Settings → Security shows backup status and all devices with their
  verification state.

## Notifications

Protea shows **local** notifications via `flutter_local_notifications`
(`lib/src/notifications.dart`): while the app is running, events that match
your server-side push rules trigger a desktop notification (suppressed for
the room you're looking at and your own messages). Clicking one jumps to the
room, switching accounts if needed. There is no background push yet —
UnifiedPush / FCM / APNs are on the roadmap.

Platform support: Windows, Linux and macOS are configured. On Windows the
app registers its AppUserModelID under `HKCU` at startup, so toasts work
without an MSIX package — but Windows only lets packaged apps *withdraw* a
toast, so notifications for a room you have since read stay on screen until
they time out. On macOS, the system only
delivers notifications to apps signed with an Apple-issued certificate — for
development, enable automatic signing with your (free) Apple ID team in
Xcode's Signing & Capabilities tab; for distribution, sign with a Developer
ID certificate and notarize.

## Project structure

```
lib/
├── main.dart                     # App entry: bootstraps settings, accounts,
│                                 # notifications, theming, login routing
├── l10n/                         # ARB translations (en, de, es, fr, it)
└── src/
    ├── matrix.dart               # Client bootstrap: SQLite store, vodozemac
    ├── client_manager.dart       # Multi-account: one client + DB per account
    ├── settings.dart             # Persisted user settings (layout, theme, …)
    ├── themes.dart               # Material seeds + named theme palettes
    ├── notifications.dart        # Local desktop notifications
    ├── auto_away.dart            # Idle detection → away presence
    ├── channel_groups.dart       # Custom channel groups & ordering
    ├── commands.dart             # Slash-command palette and extra commands
    ├── sso.dart                  # SSO browser round-trip (localhost / deep link)
    ├── room_navigator.dart       # Opens rooms inside the active layout
    ├── room_actions.dart         # Shared invite/knock/logout dialogs
    ├── l10n.dart                 # context.l10n convenience extension
    ├── pages/
    │   ├── home_page.dart        # Picks the layout chosen in settings
    │   ├── discord_home_page.dart# Workspace & liquid layouts: rail + channels + chat
    │   ├── split_home_page.dart  # Two-pane list + chat layout
    │   ├── room_list_page.dart   # Classic flat room list
    │   ├── room_page.dart        # Timeline, composer, threads, member panel
    │   ├── login_page.dart       # Flow detection, password + SSO login
    │   └── settings_page.dart    # Tabbed settings (account, appearance,
    │                             # notifications, privacy, security, …)
    └── widgets/                  # Message rendering (HTML, images, video,
                                  # voice, polls, PDF), pickers (emoji, GIF,
                                  # sticker), room/space/E2EE dialogs,
                                  # avatars & presence
```

## Roadmap ideas

- Real push notifications (UnifiedPush / FCM / APNs) and mobile notification
  support
- QR-code scanning for device verification (showing a code works; scanning
  needs camera support, which Flutter lacks on desktop Linux)
- Voice and video calls
- Location sharing and message translation
