// The About settings page shows the build and offers updates: installed in
// place where the install location allows it, as a download otherwise.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/updater.dart';
import 'package:protea/src/widgets/update_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

Updater _updater(InstallKind kind) => Updater(
  installKind: kind,
  httpClient: () => MockClient(
    (_) async => http.Response(
      jsonEncode([
        {
          'tag_name': 'v1.2.0',
          'name': 'Protea 1.2.0',
          'body': 'Faster timeline.',
          'prerelease': false,
          'html_url':
              'https://github.com/$updateRepository/releases/tag/v1.2.0',
          'published_at': '2026-11-01T12:00:00Z',
          'assets': [
            for (final suffix in [
              '-linux-x64.zip',
              '-linux-arm64.zip',
              '-windows-x64.zip',
              '-windows-arm64.zip',
              '-macos.zip',
            ])
              {
                'name': 'protea-1.2.0$suffix',
                'browser_download_url': 'https://example.com/protea$suffix',
              },
          ],
        },
      ]),
      200,
    ),
  ),
);

Future<AppLocalizations> _pumpAbout(
  WidgetTester tester,
  AppSettings settings,
  Updater updater,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: AboutSection(settings: settings, updater: updater),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  return AppLocalizations.of(tester.element(find.byType(AboutSection)));
}

Future<void> _checkForUpdates(
  WidgetTester tester,
  AppLocalizations l10n,
  Updater updater,
) async {
  await tester.tap(find.text(l10n.checkForUpdates));
  // The check runs in the test's fake-async zone: pump it along, giving
  // the real event loop a turn in between, until it has an answer.
  for (var i = 0; i < 100 && (updater.busy || i == 0); i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(updater.busy, isFalse, reason: 'the check finished');
  await tester.pump();
}

void main() {
  PackageInfo.setMockInitialValues(
    appName: 'protea',
    packageName: 'protea',
    version: '1.1.0',
    buildNumber: '7',
    buildSignature: '',
  );

  late AppSettings settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await AppSettings.load();
  });

  testWidgets('shows the running version and build', (tester) async {
    final l10n = await _pumpAbout(
      tester,
      settings,
      _updater(InstallKind.manual),
    );
    expect(
      find.textContaining('${l10n.versionLabel} 1.1.0', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('${l10n.buildLabel} 7', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('an installable update offers install and restart', (
    tester,
  ) async {
    final updater = _updater(InstallKind.linuxUser);
    final l10n = await _pumpAbout(tester, settings, updater);

    await _checkForUpdates(tester, l10n, updater);

    expect(find.text(l10n.updateAvailable('1.2.0')), findsOneWidget);
    expect(find.text('Faster timeline.'), findsOneWidget);
    expect(find.text(l10n.installAndRestart), findsOneWidget);
    expect(find.text(l10n.updateManualInstall), findsNothing);
  });

  testWidgets('an update the app cannot install itself is a download', (
    tester,
  ) async {
    final updater = _updater(InstallKind.manual);
    final l10n = await _pumpAbout(tester, settings, updater);

    await _checkForUpdates(tester, l10n, updater);

    expect(find.text(l10n.updateAvailable('1.2.0')), findsOneWidget);
    expect(find.text(l10n.installAndRestart), findsNothing);
    expect(find.text(l10n.downloadUpdate), findsOneWidget);
    expect(find.text(l10n.updateManualInstall), findsOneWidget);
  });

  testWidgets('the beta switch persists', (tester) async {
    final l10n = await _pumpAbout(
      tester,
      settings,
      _updater(InstallKind.manual),
    );
    expect(settings.betaUpdates, isFalse);
    await tester.tap(find.text(l10n.betaUpdatesTitle));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(settings.betaUpdates, isTrue);
  });
}
