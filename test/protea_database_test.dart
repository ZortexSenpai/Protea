// Account databases must tolerate concurrent access (the Linux app is not
// single-instance): WAL journaling plus a busy timeout, so lock contention
// waits instead of failing the sync loop with "database is locked".
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

void main() {
  test('account database opens with WAL and a busy timeout', () async {
    void overrideSqlite() {
      // Fedora ships libsqlite3.so.0 without the dev symlink sqlite3 looks
      // for; the override must run in every isolate touching the database.
      if (Platform.isLinux) {
        open.overrideFor(
          OperatingSystem.linux,
          () => DynamicLibrary.open('libsqlite3.so.0'),
        );
      }
    }

    overrideSqlite();
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('protea_db_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/test.sqlite';

    // The worker-isolate factory, like production: its busy-wait must not
    // block this isolate, which plays the part of the second app instance.
    final database = await openProteaDatabase(
      createDatabaseFactoryFfi(ffiInit: overrideSqlite),
      path,
    );
    addTearDown(database.close);

    final journalMode = (await database.rawQuery(
      'PRAGMA journal_mode',
    )).single.values.single;
    expect((journalMode as String).toLowerCase(), 'wal');

    final busyTimeout = (await database.rawQuery(
      'PRAGMA busy_timeout',
    )).single.values.single;
    expect(busyTimeout, 10000);

    // NOTE: the cross-process wait cannot be asserted under `flutter test`:
    // the Dart VM's debug-mode profiler signals interrupt sqlite's busy
    // sleeps (usleep returns EINTR ~every ms), so the 10s budget elapses in
    // ~40ms of wall time. Release builds sleep normally — verified manually
    // with a python waiter/holder pair. Here we pin down that the pragmas
    // are wired through openProteaDatabase.
  });
}
