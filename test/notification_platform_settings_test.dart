// Every desktop platform the app targets needs its own entry in the plugin's
// initialization settings: flutter_local_notifications throws when the
// running platform's settings are missing, and NotificationService swallows
// that — leaving notifications silently dead for the whole session.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/notifications.dart';

/// Stands in for the native implementation, which is not registered in the
/// test VM. `resolvePlatformSpecificImplementation` type-checks against the
/// per-platform classes and so returns null for this, leaving `initialize`
/// to do nothing beyond validating the settings it was handed.
class _StubPlatform extends FlutterLocalNotificationsPlatform {}

void main() {
  const desktopPlatforms = <TargetPlatform>[
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ];

  test('settings are present for every desktop platform', () {
    final settings = NotificationService.initializationSettings;
    expect(settings.linux, isNotNull);
    expect(settings.macOS, isNotNull);
    expect(settings.windows, isNotNull);
  });

  test('the Windows app identity is well formed', () {
    final windows = NotificationService.initializationSettings.windows!;
    expect(windows.appName, isNotEmpty);
    // CompanyName.ProductName[.SubProduct[.VersionInformation]]
    expect(windows.appUserModelId, matches(RegExp(r'^[\w-]+(\.[\w-]+)+$')));
    // The native side crashes on a malformed GUID, so it never reaches it.
    expect(
      windows.guid,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-'
          r'[0-9a-f]{4}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  for (final platform in desktopPlatforms) {
    test('the plugin accepts the settings on $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      FlutterLocalNotificationsPlatform.instance = _StubPlatform();
      try {
        // The real plugin throws an ArgumentError when the running platform's
        // settings are missing — which is exactly how Windows notifications
        // used to die, silently, inside NotificationService's catch.
        await expectLater(
          FlutterLocalNotificationsPlugin().initialize(
            settings: NotificationService.initializationSettings,
          ),
          completes,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
