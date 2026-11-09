// GIF picker: favorites live in account data (like sticker packs), the
// star button toggles them, and the Favorites view works without a Klipy
// API key.
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/l10n.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/widgets/gif_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

Future<void> _seedFavorite(Client client, String name) {
  return client.handleSync(
    SyncUpdate(
      nextBatch: 'favs',
      accountData: [
        BasicEvent(
          type: favoriteGifsAccountData,
          content: {
            'gifs': [
              {
                'url': 'https://gifs.example/$name.gif',
                'preview_url': 'https://gifs.example/$name-sm.gif',
                'title': name,
              },
            ],
          },
        ),
      ],
    ),
  );
}

Widget _app(Client client, AppSettings settings) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        SettingsScope(settings: settings, child: child ?? const SizedBox()),
    home: Scaffold(
      body: GifPickerPanel(client: client, onPicked: (_) {}, onClose: () {}),
    ),
  );
}

void main() {
  testWidgets('favorites persist to account data and toggle off', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      await _seedFavorite(client, 'party cat');
      settings = await AppSettings.load();
    });

    await tester.pumpWidget(_app(client, settings));
    await tester.pumpAndSettle();

    // No Klipy key but a stored favorite: the picker starts on Favorites
    // and shows the tile (image load fails in tests; the tile remains).
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GifPickerPanel)),
    );
    expect(find.text(l10n.noFavoriteGifsHint), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);

    // Hover the tile and unstar it.
    final tile = find.byType(InkWell).last;
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 3,
    );
    await mouse.addPointer(location: tester.getCenter(tile));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.removeFromFavorites));
    await tester.pumpAndSettle();

    expect(find.text(l10n.noFavoriteGifsHint), findsOneWidget);
    // The empty list was saved back to account data.
    final saved = FakeMatrixApi.calledEndpoints.entries
        .where((e) => e.key.contains('account_data/energy.vgt.protea'))
        .expand((e) => e.value)
        .toList();
    expect(saved, isNotEmpty);
    expect(
      (jsonDecode(saved.last as String) as Map<String, dynamic>)['gifs'],
      isEmpty,
    );

    // Trending needs a key: switching shows the setup hint.
    await tester.tap(find.text(l10n.trending));
    await tester.pumpAndSettle();
    expect(find.text(l10n.gifSearchNeedsKlipyKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => client.dispose(closeDatabase: false));
  });
}
