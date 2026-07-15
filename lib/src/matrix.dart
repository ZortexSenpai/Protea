import 'dart:io';

import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'commands.dart';
import 'widgets/space_banner.dart';

bool _vodozemacInitialized = false;

/// Builds a Matrix [Client] named [name] with a platform-appropriate SQLite
/// backend and restores its previous session from disk if one exists. Each
/// account uses its own database file derived from [name].
Future<Client> buildMatrixClient({String name = 'Protea'}) async {
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
  final database = await MatrixSdkDatabase.init(
    dbName,
    database: await dbFactory.openDatabase(p.join(dir.path, '$dbName.sqlite')),
    sqfliteFactory: dbFactory,
    fileStorageLocation: fileStorage.uri,
    maxFileSize: 10 * 1024 * 1024,
  );

  final client = Client(
    name,
    database: database,
    logLevel: Level.warning,
    // Without this, checkHomeserver rejects homeservers that only offer SSO
    // (the SDK default is password-only).
    supportedLoginTypes: {
      AuthenticationTypes.password,
      AuthenticationTypes.sso,
    },
    // Custom state events are dropped from partially-loaded rooms unless
    // they are listed here (the SDK adds its own defaults to this set).
    importantStateEvents: {spaceBannerEventType},
    verificationMethods: {
      KeyVerificationMethod.emoji,
      KeyVerificationMethod.numbers,
    },
  );
  registerProteaCommands(client);

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
