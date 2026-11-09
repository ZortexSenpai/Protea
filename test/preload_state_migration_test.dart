// States stored before their type joined importantStateEvents sit in the
// non-preload table where neither startup preloading nor postLoad can reach
// them once the type becomes important. movePreloadStates rescues them.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/matrix.dart';
import 'package:protea/src/widgets/sticker_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

void main() {
  test('stranded im.ponies.room_emotes states move to the preload box', () async {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
    sqfliteFfiInit();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(singleInstance: false),
    );
    for (final table in [
      'box_preload_room_states',
      'box_non_preload_room_states',
    ]) {
      await db.execute(
        'CREATE TABLE $table (k TEXT PRIMARY KEY NOT NULL, v TEXT)',
      );
    }
    // A pack state stored by an old build, plus an unrelated state that
    // must stay where it is.
    await db.insert('box_non_preload_room_states', {
      'k': '!room:server|$roomEmotesStateType|topgear',
      'v': '{"type":"$roomEmotesStateType","content":{}}',
    });
    await db.insert('box_non_preload_room_states', {
      'k': '!room:server|m.room.topic|',
      'v': '{"type":"m.room.topic","content":{}}',
    });

    await movePreloadStates(db);

    final preload = await db.query('box_preload_room_states');
    final nonPreload = await db.query('box_non_preload_room_states');
    expect(preload.map((r) => r['k']), [
      '!room:server|$roomEmotesStateType|topgear',
    ]);
    expect(nonPreload.map((r) => r['k']), ['!room:server|m.room.topic|']);

    // Running again is a harmless no-op.
    await movePreloadStates(db);
    expect((await db.query('box_preload_room_states')).length, 1);

    await db.close();
  });

  test('movePreloadStates is a no-op on a fresh database', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(singleInstance: false),
    );
    // No box tables exist yet — must not throw.
    await movePreloadStates(db);
    await db.close();
  });
}
