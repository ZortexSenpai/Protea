# Protea

A cross-platform [Matrix](https://matrix.org) chat client built with Flutter.
One codebase, native builds for **Windows, macOS, Linux, iOS and Android**.

Built on the [matrix](https://pub.dev/packages/matrix) Dart SDK (the same SDK
that powers FluffyChat), with a SQLite store so your session and room cache
survive restarts.

## Features

- Sign in to any Matrix homeserver (password login)
- Single sign-on (SSO / OIDC) login, including per-provider buttons on
  homeservers with multiple identity providers (MSC2858)
- Session persistence — sign in once, stay signed in
- Discord-style layout: spaces rail, channel list per space and — on wide
  screens — the chat pane alongside (responsive: single column on phones)
- Settings page: switch between Discord-style and classic list layout, move
  the spaces rail left/right, pick light/dark/system theme (all persisted)
- Room list with last message previews, timestamps and unread badges
- Accept or reject room invitations
- Full message timeline with infinite scroll-back history
- Send and receive text messages with local echo and error indicators
- Light and dark theme following the system setting

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.35 or newer) on your `PATH`.

```sh
flutter pub get
flutter run          # runs on the connected device / current desktop OS
```

### Platform notes

| Platform | Requirements |
|----------|--------------|
| Linux    | `clang`, `cmake`, `ninja-build`, `gtk3-devel` (Fedora: `sudo dnf install clang cmake ninja-build gtk3-devel`) |
| Windows  | Visual Studio 2022 with the “Desktop development with C++” workload |
| macOS    | Xcode (network client entitlement is already configured) |
| iOS      | Xcode + an Apple developer account for device deployment |
| Android  | Android Studio / Android SDK (INTERNET permission is already configured) |

Build release artifacts with `flutter build <linux|windows|macos|ipa|apk>`.

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

The Matrix SDK supports E2EE through [vodozemac](https://github.com/matrix-org/vodozemac),
but it is not yet wired into this app: encrypted rooms are shown with a banner
and the composer is disabled there. To enable E2EE:

1. Install a [Rust toolchain](https://rustup.rs) (needed at build time).
2. `flutter pub add flutter_vodozemac`
3. In `lib/main.dart`, initialize it before building the client:

   ```dart
   import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vodozemac;
   ...
   await vodozemac.init();   // before buildMatrixClient()
   ```

The SDK picks it up automatically (`Client` enables encryption whenever
vodozemac is initialized) — no further app changes needed for basic E2EE.
Device verification and key backup UI would still need to be built.

## Project structure

```
lib/
├── main.dart                     # App entry, theming, login-state routing
└── src/
    ├── matrix.dart               # Client + SQLite database bootstrap
    ├── settings.dart             # Persisted user settings (layout, theme)
    ├── sso.dart                  # SSO browser round-trip (localhost / deep link)
    ├── room_actions.dart         # Shared invite/logout dialogs
    ├── pages/
    │   ├── home_page.dart        # Switches between the two layouts
    │   ├── discord_home_page.dart# Spaces rail + channel list + chat pane
    │   ├── room_list_page.dart   # Classic flat room list
    │   ├── settings_page.dart    # Layout, rail position, theme, account
    │   ├── login_page.dart       # Flow detection, password + SSO login
    │   └── room_page.dart        # Timeline, history paging, composer
    └── widgets/
        └── initials_avatar.dart  # Deterministic letter avatars
```

## Roadmap ideas

- E2EE (see above), device verification, key backup
- Media messages: images, files, audio (SDK: `room.sendFileEvent`)
- Avatars and media rendering via authenticated media endpoints
- Reactions, replies and edits (data is already in the timeline)
- Push notifications (UnifiedPush / FCM / APNs)
- Room creation, direct messages and user search
