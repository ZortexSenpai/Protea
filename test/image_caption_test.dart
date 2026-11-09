// Images (and other attachments) sent with a caption must show that caption
// under the media. The caption is the event's own `body`, which MSC2530 turns
// into a caption whenever a separate `filename` is present — not the SDK's
// localized fallback ("… sent a picture").
import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

MatrixEvent _imageEvent({
  required String eventId,
  required String filename,
  String? body,
  int tsOffset = 0,
}) => MatrixEvent(
  type: 'm.room.message',
  content: {
    'msgtype': 'm.image',
    // Clients following MSC2530 leave the body out entirely when a picture
    // has no caption.
    'body': ?body,
    'filename': filename,
    'url': 'mxc://fake/$eventId',
    'info': {'mimetype': 'image/png', 'w': 100, 'h': 100, 'size': 1234},
  },
  senderId: fakeUserId,
  eventId: eventId,
  originServerTs: DateTime.fromMillisecondsSinceEpoch(1700000000000 + tsOffset),
);

void main() {
  testWidgets('captioned images render their caption, plain ones do not', (
    tester,
  ) async {
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
                    // A caption: body differs from the real file name.
                    _imageEvent(
                      eventId: '\$captioned',
                      body: 'look at this cat',
                      filename: 'cat.png',
                    ),
                    // No caption: body is the file name, filename repeats it.
                    _imageEvent(
                      eventId: '\$plain',
                      body: 'dog.png',
                      filename: 'dog.png',
                      tsOffset: 1000,
                    ),
                    // No caption and no body at all: nothing may be pinned
                    // under the image — least of all the SDK's placeholder
                    // for an event it can't render.
                    _imageEvent(
                      eventId: '\$bodyless',
                      filename: 'bird.png',
                      tsOffset: 2000,
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

    final room = client.getRoomById('!room0:fake')!;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => SettingsScope(
          settings: settings,
          child: child ?? const SizedBox.shrink(),
        ),
        home: RoomPage(room: room),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The caption shows verbatim; the localized attachment fallback never
    // stands in for it.
    expect(find.text('look at this cat'), findsWidgets);
    expect(find.textContaining('sent a picture'), findsNothing);
    // An uncaptioned image stays bare: no file name pinned under the image.
    // ('dog.png' may still appear in the broken-image stand-in, which is why
    // this asserts on the caption text of the captioned event instead.)
    expect(find.text('cat.png'), findsNothing);
    // A picture sent without a body shows no caption line.
    expect(find.textContaining('Unknown message format'), findsNothing);

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

  testWidgets('a caption typed when attaching is sent as the body', (
    tester,
  ) async {
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

    final room = client.getRoomById('!room0:fake')!;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => SettingsScope(
          settings: settings,
          child: child ?? const SizedBox.shrink(),
        ),
        home: RoomPage(room: room),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // What is asserted below is the content the client builds, which the
    // local echo already carries. The upload itself has no fake route and
    // would retry on a timer for a fake minute, tripping the harness'
    // pending-timer check — so make the server refuse the size up front and
    // fail the send immediately instead.
    FakeMatrixApi.currentApi!.api['GET']!['/client/v1/media/config'] =
        (dynamic req) => {'m.upload.size': 1};

    // A one-pixel PNG, so the staging preview has something decodable.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8'
      'BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    // Text already in the composer is what "sending an image with a text"
    // means for someone who typed first and attached second.
    final composer = find.byType(TextField);
    await tester.enterText(composer, 'look at this cat');
    await tester.pump();

    // Fire and forget: the handler only returns once the staging dialog is
    // dismissed, which needs pumps that cannot run while awaiting it.
    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
    dropTarget.onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile.fromData(
            Uint8List.fromList(png),
            // The io XFile derives `name` from the path, not the argument.
            path: 'cat.png',
            name: 'cat.png',
            mimeType: 'image/png',
          ),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    // Not pumpAndSettle: the page keeps a progress indicator animating.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    final l10n = AppLocalizations.of(tester.element(find.byType(RoomPage)));
    // The staging dialog offers a caption field, seeded with the composer
    // text so it does not have to be retyped.
    expect(find.text(l10n.addACaption), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      'look at this cat',
    );
    await tester.tap(find.text(l10n.send));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // MSC2530 shape: the file name stays in `filename`, the caption is the
    // body other clients render.
    final sent = room.client.getRoomById('!room0:fake')!.lastEvent;
    expect(sent?.content['filename'], 'cat.png');
    expect(sent?.content['body'], 'look at this cat');
    // The composer text moved into the caption, so it must not linger.
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '',
    );

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
