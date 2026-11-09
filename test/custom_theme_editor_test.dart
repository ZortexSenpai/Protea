// Picking the Custom theme opens a six-color editor, seeded from the theme
// that was on screen so it never starts from nothing, and editing a color
// restyles the app right away.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/settings_page.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('choosing Custom opens an editor seeded from the old theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      settings = await AppSettings.load();
      await settings.setAppTheme(AppTheme.nord);
      await settings.setThemeMode(ThemeMode.dark);
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          colorScheme: schemeFor(
            AppTheme.nord,
            AppThemeColor.protea,
            Brightness.dark,
          ),
        ),
        home: SettingsScope(
          settings: settings,
          child: SettingsDialog(client: client, settings: settings),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsDialog)),
    );

    await tester.tap(find.text(l10n.appearance).first);
    await tester.pumpAndSettle();

    // The editor is built but collapsed away until Custom is selected, so
    // this asks whether it is reachable rather than whether it exists.
    expect(find.text(l10n.customThemeColors).hitTestable(), findsNothing);
    expect(settings.hasCustomPalette(Brightness.dark), isFalse);

    await tester.ensureVisible(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    expect(settings.appTheme, AppTheme.custom);
    // The six colors, seeded from Nord rather than from defaults.
    await tester.ensureVisible(find.text(l10n.customThemeColors));
    await tester.pumpAndSettle();
    expect(find.text(l10n.customThemeColors).hitTestable(), findsOneWidget);
    for (final label in [
      l10n.colorAccent,
      l10n.colorBackground,
      l10n.colorPanels,
      l10n.colorText,
      l10n.colorMutedText,
      l10n.colorOutline,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    final nord = schemeFor(
      AppTheme.nord,
      AppThemeColor.protea,
      Brightness.dark,
    );
    expect(settings.customPalette(Brightness.dark).background, nord.surface);
    expect(settings.customPalette(Brightness.dark).accent, nord.primary);

    // An accent row belongs to themes that ship a palette, not to this one.
    expect(find.text(l10n.accentColor).hitTestable(), findsNothing);

    // Drain in-flight SDK work before the harness checks for stray timers.
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(seconds: 31));
    await tester.runAsync(() => client.dispose(closeDatabase: false));
  });

  testWidgets('the theme-default swatch lines up with the colors beside it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      settings = await AppSettings.load();
      // An accent row belongs to a theme that ships its own palette.
      await settings.setAppTheme(AppTheme.nord);
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScope(
          settings: settings,
          child: SettingsDialog(client: client, settings: settings),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsDialog)),
    );

    await tester.tap(find.text(l10n.appearance).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip(l10n.themeDefault));
    await tester.pumpAndSettle();

    // A swatch of a different size would be aligned to the top of the Wrap's
    // line and read as offset, which is what this guards.
    final themeDefault = tester.getRect(find.byTooltip(l10n.themeDefault));
    final firstColor = tester.getRect(
      find.byTooltip(AppThemeColor.protea.label),
    );
    expect(themeDefault.size, firstColor.size);
    expect(themeDefault.top, firstColor.top);

    // Drain in-flight SDK work before the harness checks for stray timers.
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(seconds: 31));
    await tester.runAsync(() => client.dispose(closeDatabase: false));
  });
}
