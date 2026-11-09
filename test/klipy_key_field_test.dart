// The Klipy API key is a secret: the integrations field obscures it like a
// password, with an eye toggle to reveal it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/settings_page.dart';
import 'package:protea/src/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('Klipy API key field is obscured with a reveal toggle', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'flutter.klipyApiKey': 'super-secret-key',
    });
    late final Client client;
    late final AppSettings settings;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      settings = await AppSettings.load();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsDialog(client: client, settings: settings),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    final l10n = AppLocalizations.of(tester.element(find.byType(SettingsDialog)));

    await tester.tap(find.text(l10n.integrations));
    await tester.pumpAndSettle();

    final keyField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == l10n.klipyApiKey,
    );
    expect(keyField, findsOneWidget);
    expect(tester.widget<TextField>(keyField).obscureText, isTrue);

    // The eye toggle reveals and re-hides the key.
    await tester.tap(find.byTooltip(l10n.show));
    await tester.pump();
    expect(tester.widget<TextField>(keyField).obscureText, isFalse);
    await tester.tap(find.byTooltip(l10n.hide));
    await tester.pump();
    expect(tester.widget<TextField>(keyField).obscureText, isTrue);

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
