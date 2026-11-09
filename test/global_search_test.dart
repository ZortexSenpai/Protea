// Global message search: queries the server /search API across all rooms,
// lists results with room and sender context, and pages via next_batch.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/l10n.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/widgets/global_search_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('global search lists server results with room context', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
        builder: (context, child) =>
            SettingsScope(settings: settings, child: child ?? const SizedBox()),
        home: Scaffold(body: GlobalSearchDialog(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GlobalSearchDialog)),
    );

    // Before searching: the prompt and the encrypted-rooms caveat.
    expect(find.text(l10n.searchAllRoomsPrompt), findsOneWidget);
    expect(find.text(l10n.encryptedNotSearchable), findsOneWidget);

    // Search. FakeMatrixApi answers /search with one canned result.
    await tester.enterText(find.byType(TextField), 'example');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The canned result body renders, with the total count and a
    // more-results button for the returned next_batch.
    expect(find.text('This is an example text message'), findsOneWidget);
    expect(find.text(l10n.searchResultCount(1224)), findsOneWidget);
    expect(find.text(l10n.moreResults), findsOneWidget);

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
