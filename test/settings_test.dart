import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protea/src/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to workspace layout, left rail and system theme', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.layout, AppLayout.workspace);
    expect(settings.railPosition, RailPosition.left);
    expect(settings.themeMode, ThemeMode.system);
  });

  test('persists changes and notifies listeners', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();

    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setLayout(AppLayout.list);
    await settings.setRailPosition(RailPosition.right);
    await settings.setThemeMode(ThemeMode.dark);

    expect(notified, 3);
    expect(settings.layout, AppLayout.list);
    expect(settings.railPosition, RailPosition.right);
    expect(settings.themeMode, ThemeMode.dark);

    // A fresh instance reads the same persisted values back.
    final reloaded = await AppSettings.load();
    expect(reloaded.layout, AppLayout.list);
    expect(reloaded.railPosition, RailPosition.right);
    expect(reloaded.themeMode, ThemeMode.dark);
  });

  test('falls back to defaults on unknown stored values', () async {
    SharedPreferences.setMockInitialValues({'layout': 'does-not-exist'});
    final settings = await AppSettings.load();
    expect(settings.layout, AppLayout.workspace);
  });

  test('migrates legacy layout names', () async {
    SharedPreferences.setMockInitialValues({'layout': 'discord'});
    expect((await AppSettings.load()).layout, AppLayout.workspace);

    SharedPreferences.setMockInitialValues({'layout': 'classic'});
    expect((await AppSettings.load()).layout, AppLayout.list);
  });
}
