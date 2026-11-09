// Quick switcher (Ctrl/Cmd+T): lists rooms by recency, finds people
// people through the user directory, and supports @/# scoping plus
// arrow-key navigation. Switching rooms puts the caret in the message box.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/client_manager.dart';
import 'package:protea/src/l10n.dart';
import 'package:protea/src/pages/home_page.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/smooth_scroll.dart';
import 'package:protea/src/widgets/quick_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('quick switcher finds rooms and people', (tester) async {
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
        home: Scaffold(
          body: QuickSwitcherListener(
            client: client,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ctrl+T opens the switcher.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(QuickSwitcherDialog), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(QuickSwitcherDialog)),
    );

    // Empty query: the joined rooms, first one highlighted.
    final roomCount = client.rooms
        .where((room) => !room.isSpace && room.membership != Membership.leave)
        .length;
    expect(roomCount, greaterThan(1));
    expect(find.byType(ListTile), findsNWidgets(roomCount));
    bool selected(int index) =>
        tester.widget<ListTile>(find.byType(ListTile).at(index)).selected;
    expect(selected(0), isTrue);

    // Arrow down moves the highlight.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(selected(0), isFalse);
    expect(selected(1), isTrue);

    // "#" scopes to rooms: no directory lookup, nothing matches.
    await tester.enterText(find.byType(TextField), '#zzzz-no-match');
    await tester.pump();
    expect(find.text(l10n.noSearchResults), findsOneWidget);

    // "@" scopes to people: the user directory result shows up as a person
    // to start a chat with.
    await tester.enterText(find.byType(TextField), '@foo');
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('@foo:bar.com'), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_outlined), findsOneWidget);

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

  testWidgets('switching rooms focuses the message box', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    late final AppSettings settings;
    late final SharedPreferences prefs;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      var ts = 1700000000000;
      MatrixEvent message(String eventId, String body) => MatrixEvent(
        type: 'm.room.message',
        content: {'msgtype': 'm.text', 'body': body},
        senderId: fakeUserId,
        eventId: eventId,
        originServerTs: DateTime.fromMillisecondsSinceEpoch(ts += 1000),
      );
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'focus-batch',
          rooms: RoomsUpdate(
            join: {
              for (final (i, name) in [(0, 'alpha'), (1, 'beta')])
                '!room$i:fake': JoinedRoomUpdate(
                  timeline: TimelineUpdate(
                    events: [
                      MatrixEvent(
                        type: 'm.room.name',
                        content: {'name': '$name chat'},
                        senderId: fakeUserId,
                        eventId: '\$name$i',
                        originServerTs: DateTime.fromMillisecondsSinceEpoch(ts),
                        stateKey: '',
                      ),
                      for (var m = 0; m < 30; m++)
                        message('\$msg$i-$m', 'message $m in $name'),
                    ],
                  ),
                  state: [
                    MatrixEvent(
                      type: 'm.room.member',
                      content: {'membership': 'join', 'displayname': 'Test'},
                      senderId: fakeUserId,
                      eventId: '\$member$i',
                      originServerTs: DateTime.fromMillisecondsSinceEpoch(ts),
                      stateKey: fakeUserId,
                    ),
                  ],
                ),
            },
          ),
        ),
      );
      prefs = await SharedPreferences.getInstance();
      settings = await AppSettings.load();
    });
    final manager = ClientManager.forTesting(prefs, [client]);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => SettingsScope(
          settings: settings,
          child: SmoothScrolling(
            enabled: true,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: QuickSwitcherListener(
          client: client,
          child: HomePage(client: client, manager: manager, settings: settings),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    Finder composerOf(String roomId) => find.descendant(
      of: find.byWidgetPredicate((w) => w is RoomPage && w.room.id == roomId),
      matching: find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Message',
      ),
    );
    bool composerFocused(String roomId) =>
        tester.widget<TextField>(composerOf(roomId)).focusNode!.hasPrimaryFocus;

    Future<void> quickSwitch(String query) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.descendant(
          of: find.byType(QuickSwitcherDialog),
          matching: find.byType(TextField),
        ),
        query,
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      // Past the dialog's fade-out and the chat pane's cross-fade.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(QuickSwitcherDialog), findsNothing);
    }

    // Typing in alpha's message box, the usual state before Ctrl+T.
    await tester.tap(find.text('alpha chat').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(composerOf('!room0:fake'));
    await tester.pump();
    expect(composerFocused('!room0:fake'), isTrue);

    // Switching to another room: its message box takes the caret.
    await quickSwitch('#beta');
    expect(composerOf('!room0:fake'), findsNothing);
    expect(composerFocused('!room1:fake'), isTrue);

    // Picking the room that is already open focuses its message box too.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(composerFocused('!room1:fake'), isFalse);
    await quickSwitch('#beta');
    expect(composerFocused('!room1:fake'), isTrue);

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
