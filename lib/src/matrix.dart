import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:http/http.dart' as http;
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'commands.dart';
import 'logging_http_client.dart';
import 'widgets/room_banner.dart';
import 'widgets/sticker_picker.dart';

bool _vodozemacInitialized = false;

/// Opens an account database with pragmas that tolerate concurrent access —
/// the Linux app is deliberately not single-instance, so a second Protea
/// (say, a dev build next to the installed one) can hold locks on the same
/// file. WAL lets readers proceed during writes, and the busy timeout waits
/// out short lock contention instead of failing the sync loop with
/// "database is locked".
Future<Database> openProteaDatabase(DatabaseFactory factory, String path) =>
    factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.rawQuery('PRAGMA busy_timeout = 10000');
        },
      ),
    );

/// Rescues state events stored before their type joined
/// [Client.importantStateEvents]: the SDK routes states into a preload or
/// non-preload table when they are *stored*, so after a type becomes
/// important, its old rows are stranded — startup only reads the preload
/// table and postLoad skips important types. Without this, MSC2545 room
/// sticker/emote packs synced by older builds never show up again.
Future<void> movePreloadStates(Database db) async {
  const types = [roomEmotesStateType, roomBannerEventType];
  try {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
      "('box_preload_room_states', 'box_non_preload_room_states')",
    );
    if (tables.length < 2) return;
    for (final type in types) {
      await db.transaction((txn) async {
        await txn.rawInsert(
          'INSERT OR REPLACE INTO box_preload_room_states (k, v) '
          'SELECT k, v FROM box_non_preload_room_states WHERE k LIKE ?',
          ['%|$type|%'],
        );
        await txn.rawDelete(
          'DELETE FROM box_non_preload_room_states WHERE k LIKE ?',
          ['%|$type|%'],
        );
      });
    }
  } catch (e, s) {
    Logs().w('Failed to move stranded preload states', e, s);
  }
}

/// Builds a Matrix [Client] named [name] with a platform-appropriate SQLite
/// backend and restores its previous session from disk if one exists. Each
/// account uses its own database file derived from [name].
///
/// [syncPresence] is applied before the first sync request goes out, so an
/// account never advertises a presence it shouldn't (syncing without one
/// marks the account online).
Future<Client> buildMatrixClient({
  String name = 'Protea',
  PresenceType? syncPresence,
}) async {
  final dir = await getApplicationSupportDirectory();
  final fileStorage = Directory(p.join(dir.path, 'media'));
  await fileStorage.create(recursive: true);

  // Initialize the vodozemac crypto library once. The SDK enables E2EE (and
  // with it device verification) automatically when this succeeded.
  if (!_vodozemacInitialized) {
    try {
      await vod.init();
      _vodozemacInitialized = true;
    } catch (e, s) {
      Logs().e('Failed to initialize end-to-end encryption', e, s);
    }
  }

  final DatabaseFactory dbFactory;
  if (Platform.isAndroid || Platform.isIOS) {
    dbFactory = sqflite.databaseFactory;
  } else {
    // Windows, macOS and Linux use the FFI implementation backed by the
    // sqlite3 library bundled through sqlite3_flutter_libs.
    sqfliteFfiInit();
    dbFactory = databaseFactoryFfi;
  }

  // 'Protea' maps to the pre-multi-account names so existing sessions keep
  // working: database 'protea' in 'protea.sqlite'.
  final dbName = name.toLowerCase();
  final sqfliteDb = await openProteaDatabase(
    dbFactory,
    p.join(dir.path, '$dbName.sqlite'),
  );
  await movePreloadStates(sqfliteDb);
  final database = await MatrixSdkDatabase.init(
    dbName,
    database: sqfliteDb,
    sqfliteFactory: dbFactory,
    fileStorageLocation: fileStorage.uri,
    maxFileSize: 10 * 1024 * 1024,
  );

  final client = Client(
    name,
    database: database,
    logLevel: Level.warning,
    // The generated API discards the status code and body of failed
    // requests, reporting only 'http error response'. Log them so a proxy
    // or gateway failure can be told apart from a Matrix-level one.
    httpClient: LoggingHttpClient(http.Client()),
    // Heavy lifting (image shrinking for thumbnails, attachment
    // decryption, backup key generation) runs in a background isolate;
    // the SDK default runs it on the UI thread and freezes the app.
    nativeImplementations: NativeImplementationsIsolate(
      compute,
      vodozemacInit: () => vod.init(),
    ),
    // Without this, checkHomeserver rejects homeservers that only offer SSO
    // (the SDK default is password-only).
    supportedLoginTypes: {
      AuthenticationTypes.password,
      AuthenticationTypes.sso,
    },
    // Custom state events are dropped from partially-loaded rooms unless
    // they are listed here (the SDK adds its own defaults to this set).
    importantStateEvents: {roomBannerEventType, roomEmotesStateType},
    verificationMethods: {
      KeyVerificationMethod.emoji,
      KeyVerificationMethod.numbers,
      // Show-only QR verification: the other device (Element/FluffyChat
      // mobile) scans Protea's QR code. Scanning is not offered — desktop
      // Linux has no usable camera plugin.
      KeyVerificationMethod.qrShow,
      KeyVerificationMethod.reciprocate,
    },
  );
  registerProteaCommands(client);
  client.syncPresence = syncPresence;

  try {
    await client.init(
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );
  } catch (e, s) {
    Logs().e('Failed to restore session', e, s);
  }
  return client;
}
