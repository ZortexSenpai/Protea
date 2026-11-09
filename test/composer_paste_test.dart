// Ctrl/Cmd+V in the composer. Files copied in a file manager are offered for
// sending instead of pasting their names, which come along as text (and, on
// macOS, the file's icon as image data, which must not be sent either).
// Without files the text pastes as usual and an image on the clipboard is
// offered as well.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

// A one-pixel PNG, so the staging preview has something decodable.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8'
  'BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Fakes the system clipboard: [files] for pasteboard's (and, on macOS, the
/// runner's) file list — or a failing lookup when null — plus [image] and
/// [text]. Returns the names of the clipboard calls made.
List<String> _fakeClipboard(
  WidgetTester tester, {
  List<String>? files = const [],
  Uint8List? image,
  String? text,
}) {
  final calls = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  Future<Object?> filesOrImage(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'files':
        if (files == null) throw PlatformException(code: 'unavailable');
        return files;
      case 'image':
        return image;
    }
    return null;
  }

  for (final channel in const [
    MethodChannel('pasteboard'),
    MethodChannel('protea/clipboard'),
  ]) {
    messenger.setMockMethodCallHandler(channel, filesOrImage);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    switch (call.method) {
      case 'Clipboard.getData':
        calls.add(call.method);
        return text == null ? null : {'text': text};
      case 'Clipboard.hasStrings':
        return {'value': text != null};
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

Future<Client> _pumpRoom(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  late final Client client;
  late final AppSettings settings;
  await tester.runAsync(() async {
    client = await buildFakeClient();
    await client.handleSync(
      SyncUpdate(
        nextBatch: 'b1',
        rooms: RoomsUpdate(
          join: {
            '!room0:fake': JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: 'm.room.message',
                    content: {'msgtype': 'm.text', 'body': 'hi'},
                    senderId: fakeUserId,
                    eventId: '\$hi',
                    originServerTs: DateTime.fromMillisecondsSinceEpoch(
                      1700000000000,
                    ),
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    settings = await AppSettings.load();
  });
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => SettingsScope(
        settings: settings,
        child: child ?? const SizedBox.shrink(),
      ),
      home: RoomPage(room: client.getRoomById('!room0:fake')!),
    ),
  );
  await _settle(tester);
  return client;
}

/// Not pumpAndSettle: the page keeps a progress indicator animating, and
/// the paste reads real files, which only progresses in runAsync windows.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pressPaste(WidgetTester tester) async {
  await tester.showKeyboard(find.byType(TextField));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await _settle(tester);
}

String _composerText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

/// Also fine with the staging dialog still open: cancelling it would hit
/// its caption controllers being disposed before its exit animation ends.
Future<void> _tearDown(WidgetTester tester, Client client) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pump(const Duration(seconds: 31));
  await tester.runAsync(() => client.dispose(closeDatabase: false));
}

void main() {
  testWidgets('copied files are offered for sending, not pasted as text', (
    tester,
  ) async {
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('protea_paste_test'),
    );
    addTearDown(() => dir!.deleteSync(recursive: true));
    final file = File('${dir!.path}/cat.png');
    await tester.runAsync(() => file.writeAsBytes(_png));

    final client = await _pumpRoom(tester);
    final calls = _fakeClipboard(
      tester,
      // A folder in the selection is skipped.
      files: [file.path, dir.path],
      // What a file manager puts on the clipboard next to the files.
      image: Uint8List.fromList(_png),
      text: 'cat.png',
    );
    await _pressPaste(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(RoomPage)));
    expect(find.text(l10n.sendFilesTitle(1)), findsOneWidget);
    expect(find.textContaining('cat.png ·'), findsOneWidget);
    expect(_composerText(tester), '');
    // Neither the file name nor the icon image is read.
    expect(calls, isNot(contains('Clipboard.getData')));
    expect(calls, isNot(contains('image')));

    await _tearDown(tester, client);
  });

  testWidgets('without files, text pastes and an image is offered too', (
    tester,
  ) async {
    final client = await _pumpRoom(tester);
    _fakeClipboard(tester, image: Uint8List.fromList(_png), text: 'hello');
    await _pressPaste(tester);

    expect(_composerText(tester), 'hello');
    expect(find.textContaining('pasted-image.png ·'), findsOneWidget);

    await _tearDown(tester, client);
  });

  testWidgets('text still pastes when the file lookup fails', (tester) async {
    final client = await _pumpRoom(tester);
    _fakeClipboard(tester, files: null, text: 'hello');
    await _pressPaste(tester);

    expect(_composerText(tester), 'hello');
    expect(find.byType(AlertDialog), findsNothing);

    await _tearDown(tester, client);
  });
}
