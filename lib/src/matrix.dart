import 'dart:io';

import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds the Matrix [Client] with a platform-appropriate SQLite backend and
/// restores a previous session from disk if one exists.
Future<Client> buildMatrixClient() async {
  final dir = await getApplicationSupportDirectory();
  final fileStorage = Directory(p.join(dir.path, 'media'));
  await fileStorage.create(recursive: true);

  final DatabaseFactory dbFactory;
  if (Platform.isAndroid || Platform.isIOS) {
    dbFactory = sqflite.databaseFactory;
  } else {
    // Windows, macOS and Linux use the FFI implementation backed by the
    // sqlite3 library bundled through sqlite3_flutter_libs.
    sqfliteFfiInit();
    dbFactory = databaseFactoryFfi;
  }

  final database = await MatrixSdkDatabase.init(
    'protea',
    database: await dbFactory.openDatabase(p.join(dir.path, 'protea.sqlite')),
    sqfliteFactory: dbFactory,
    fileStorageLocation: fileStorage.uri,
    maxFileSize: 10 * 1024 * 1024,
  );

  final client = Client(
    'Protea',
    database: database,
    logLevel: Level.warning,
    // Without this, checkHomeserver rejects homeservers that only offer SSO
    // (the SDK default is password-only).
    supportedLoginTypes: {
      AuthenticationTypes.password,
      AuthenticationTypes.sso,
    },
  );

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
