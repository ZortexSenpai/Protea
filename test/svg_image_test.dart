// SVG images: the engine's codecs only decode bitmaps, so `Image.memory`
// fails on SVG attachments ("Invalid image data"). They are drawn with
// flutter_svg instead, and sent with a size and a PNG thumbnail.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/pages/room_page.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/svg.dart';
import 'package:protea/src/widgets/event_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

/// A 40×20 red rectangle, preceded by the XML declaration and comment that
/// editor exports put before the root element.
const _svg =
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!-- Generator: some editor -->\n'
    '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20">'
    '<rect width="40" height="20" fill="#ff0000"/></svg>';

/// A one-pixel PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8'
  'BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// An image event whose attachment comes from memory: the fake media
/// repository can only answer with JSON.
class _LocalImageEvent extends Event {
  _LocalImageEvent(this.bytes, {required String id, required super.room})
    : super(
        type: EventTypes.Message,
        content: {
          'msgtype': MessageTypes.Image,
          'body': '$id.svg',
          // Distinct per event: EventImage caches downloads by mxc URL.
          'url': 'mxc://fake/$id',
          'info': {
            'mimetype': 'image/svg+xml',
            'w': 40,
            'h': 20,
            'size': bytes.length,
          },
        },
        eventId: '\$$id',
        senderId: fakeUserId,
        originServerTs: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        status: EventStatus.synced,
      );

  final Uint8List bytes;

  @override
  Future<MatrixFile> downloadAndDecryptAttachment({
    bool getThumbnail = false,
    Future<Uint8List> Function(Uri)? downloadCallback,
    bool fromLocalStoreOnly = false,
    bool skipScanner = false,
    void Function(int)? onDownloadProgress,
  }) async => MatrixFile(bytes: bytes, name: body);
}

/// Lets real-async work (flutter_svg parses on a background isolate)
/// finish between frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _disposeClient(WidgetTester tester, Client client) async {
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
  test('looksLikeSvg tells SVG documents from bitmaps and other markup', () {
    expect(looksLikeSvg(_bytes(_svg)), isTrue);
    expect(looksLikeSvg(_bytes('<svg viewBox="0 0 1 1"/>')), isTrue);
    // Byte order mark and leading whitespace.
    expect(
      looksLikeSvg(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('\n  <svg/>')]),
      ),
      isTrue,
    );
    expect(looksLikeSvg(_png), isFalse);
    expect(looksLikeSvg(_bytes('<!DOCTYPE html><html></html>')), isFalse);
    expect(looksLikeSvg(_bytes('a text file mentioning <svg>')), isFalse);
    expect(looksLikeSvg(Uint8List(0)), isFalse);
  });

  testWidgets('rasterizeSvg draws the document into a fitting PNG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final small = (await rasterizeSvg(_bytes(_svg), maxExtent: 10))!;
      expect((small.width, small.height), (10, 5));
      expect((small.intrinsicWidth, small.intrinsicHeight), (40, 20));
      final codec = await ui.instantiateImageCodec(small.png);
      final image = (await codec.getNextFrame()).image;
      expect((image.width, image.height), (10, 5));
      final pixels = (await image.toByteData())!;
      // RGBA of the center pixel: the rectangle's red.
      final center = (2 * 10 + 5) * 4;
      expect(
        [for (var i = 0; i < 4; i++) pixels.getUint8(center + i)],
        [255, 0, 0, 255],
      );
      image.dispose();
      codec.dispose();

      // Never scaled up beyond the document's own size.
      final full = (await rasterizeSvg(_bytes(_svg), maxExtent: 800))!;
      expect((full.width, full.height), (40, 20));

      expect(await rasterizeSvg(_bytes('<svg'), maxExtent: 800), isNull);
    });
  });

  testWidgets('SVG image events render in the timeline and the viewer', (
    tester,
  ) async {
    late final Client client;
    await tester.runAsync(() async => client = await buildFakeClient());
    final room = Room(id: '!svg:fake', client: client);

    final good = _LocalImageEvent(_bytes(_svg), id: 'good', room: room);
    final broken = _LocalImageEvent(
      _bytes('<svg><rect'),
      id: 'bad',
      room: room,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EventImage(key: const Key('timeline'), event: good),
              SizedBox(
                width: 400,
                height: 300,
                // As in ImageViewerPage: centered, so the image picks its
                // own size.
                child: Center(
                  child: EventImage(
                    key: const Key('viewer'),
                    event: good,
                    thumbnail: false,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              EventImage(key: const Key('broken'), event: broken),
            ],
          ),
        ),
      ),
    );
    await _settle(tester);

    for (final key in ['timeline', 'viewer']) {
      final image = find.byKey(Key(key));
      expect(
        find.descendant(of: image, matching: find.byType(SvgPicture)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: image,
          matching: find.byIcon(Icons.broken_image_outlined),
        ),
        findsNothing,
        reason: '$key: a parseable SVG must not fall back to the error icon',
      );
      expect(
        find.descendant(of: image, matching: find.byType(Image)),
        findsNothing,
        reason: '$key: SVG bytes must not reach the bitmap decoder',
      );
    }
    // The viewer lays the image out at its reported 40×20, never scaled up.
    expect(tester.getSize(find.byKey(const Key('viewer'))), const Size(40, 20));
    // An unparseable document shows the broken-image icon instead.
    expect(
      find.descendant(
        of: find.byKey(const Key('broken')),
        matching: find.byIcon(Icons.broken_image_outlined),
      ),
      findsOneWidget,
    );

    await _disposeClient(tester, client);
  });

  testWidgets('an SVG dropped without a mimetype is sent as a sized image', (
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
    await _settle(tester);

    // The local echo carries the content under test; refuse the upload by
    // size so the send fails at once instead of retrying on timers.
    FakeMatrixApi.currentApi!.api['GET']!['/client/v1/media/config'] =
        (dynamic req) => {'m.upload.size': 1};

    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
    dropTarget.onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile.fromData(
            _bytes(_svg),
            path: 'logo.svg',
            name: 'logo.svg',
          ),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await _settle(tester);

    // The staging dialog previews the SVG itself.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SvgPicture),
      ),
      findsOneWidget,
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(RoomPage)));
    await tester.tap(find.text(l10n.send));
    await _settle(tester);

    final events = await tester.runAsync(
      () => room.client.database.getEventList(room),
    );
    final image = events!.firstWhere(
      (event) => event.messageType == MessageTypes.Image,
    );
    expect(image.content['body'], 'logo.svg');
    expect(image.infoMap['mimetype'], 'image/svg+xml');
    // The size comes from the document, which the engine can't decode.
    expect((image.infoMap['w'], image.infoMap['h']), (40, 20));

    await _disposeClient(tester, client);
  });
}
