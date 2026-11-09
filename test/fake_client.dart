// Shared helper: a logged-in matrix Client backed by FakeMatrixApi and an
// in-memory sqlite database, for widget tests that drive real app pages.
import 'dart:ffi';
import 'dart:io';

import 'package:matrix/matrix.dart';
import 'package:protea/src/widgets/room_banner.dart';
import 'package:protea/src/widgets/sticker_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

const fakeHomeserver = 'https://fakeserver.notexisting';
const fakeUserId = '@test:fakeServer.notExisting';

var _clientCounter = 0;

Future<Client> buildFakeClient({String name = 'Protea'}) async {
  // Fedora ships libsqlite3.so.0 without the dev symlink sqlite3 looks for.
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  }
  sqfliteFfiInit();
  final database = await MatrixSdkDatabase.init(
    'test_${_clientCounter++}',
    database: await databaseFactoryFfiNoIsolate.openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(singleInstance: false),
    ),
    sqfliteFactory: databaseFactoryFfiNoIsolate,
  );
  final client = Client(
    name,
    httpClient: FakeMatrixApi(),
    database: database,
    // Mirrors buildMatrixClient: custom state events are dropped from
    // partially-loaded rooms unless registered here.
    importantStateEvents: {roomBannerEventType, roomEmotesStateType},
  );
  FakeMatrixApi.client = client;
  // History requested after a limited (gappy) sync; empty page ends it.
  for (var r = 0; r < 3; r++) {
    FakeMatrixApi
            .currentApi!
            .api['GET']!['/client/v3/rooms/!room$r%3Afake/messages?from=prevtoken&dir=b&limit=30&filter=%7B%22lazy_load_members%22%3Atrue%7D'] =
        (dynamic req) => {'chunk': <dynamic>[], 'start': 'prevtoken'};
  }
  await client.checkHomeserver(
    Uri.parse(fakeHomeserver),
    checkWellKnown: false,
  );
  await client.init(
    newToken: 'abcd',
    newUserID: fakeUserId,
    newHomeserver: client.homeserver,
    newDeviceName: 'test',
    newDeviceID: 'TESTDEVICE',
  );
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await client.abortSync();
  return client;
}
