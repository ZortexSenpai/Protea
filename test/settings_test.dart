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

  test(
    'the GIF proxy is on by default and stays off once switched off',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      expect(settings.gifProxyEnabled, isTrue);
      expect(settings.gifProxyServer, 'gifs.sable.moe');

      // Whether an own Klipy key is set makes no difference to the default.
      await settings.setKlipyApiKey('secret');
      expect(settings.gifProxyEnabled, isTrue);

      await settings.setGifProxyEnabled(false);
      await settings.setKlipyApiKey('');
      expect(settings.gifProxyEnabled, isFalse);

      final reloaded = await AppSettings.load();
      expect(reloaded.gifProxyEnabled, isFalse);
    },
  );

  test('site link previews start on and switch off one by one', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(PreviewSite.values.every(settings.sitePreviewEnabled), isTrue);

    await settings.setSitePreviewEnabled(PreviewSite.reddit, false);
    final reloaded = await AppSettings.load();
    expect(reloaded.sitePreviewEnabled(PreviewSite.reddit), isFalse);
    expect(reloaded.sitePreviewEnabled(PreviewSite.youtube), isTrue);

    await reloaded.setSitePreviewEnabled(PreviewSite.reddit, true);
    expect(reloaded.sitePreviewEnabled(PreviewSite.reddit), isTrue);
  });

  test('persists changes and notifies listeners', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();

    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setLayout(AppLayout.liquid);
    await settings.setRailPosition(RailPosition.right);
    await settings.setThemeMode(ThemeMode.dark);

    expect(notified, 3);
    expect(settings.layout, AppLayout.liquid);
    expect(settings.railPosition, RailPosition.right);
    expect(settings.themeMode, ThemeMode.dark);

    // A fresh instance reads the same persisted values back.
    final reloaded = await AppSettings.load();
    expect(reloaded.layout, AppLayout.liquid);
    expect(reloaded.railPosition, RailPosition.right);
    expect(reloaded.themeMode, ThemeMode.dark);
  });

  test('falls back to defaults on unknown stored values', () async {
    SharedPreferences.setMockInitialValues({'layout': 'does-not-exist'});
    final settings = await AppSettings.load();
    expect(settings.layout, AppLayout.workspace);
  });

  test('legacy and removed layout names fall back to workspace', () async {
    for (final legacy in ['discord', 'classic', 'split', 'list']) {
      SharedPreferences.setMockInitialValues({'layout': legacy});
      expect((await AppSettings.load()).layout, AppLayout.workspace);
    }
  });

  test(
    'arrow-up-to-edit is on by default and persists when disabled',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      expect(settings.arrowUpToEdit, isTrue);

      await settings.setArrowUpToEdit(false);
      expect(settings.arrowUpToEdit, isFalse);
      expect((await AppSettings.load()).arrowUpToEdit, isFalse);
    },
  );
}
