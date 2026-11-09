import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:protea/src/client_manager.dart';
import 'package:protea/src/presence_service.dart';
import 'package:protea/src/settings.dart';

import 'fake_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only the active account advertises its chosen presence', () {
    expect(
      effectiveSyncPresence(PresenceType.online, active: true),
      PresenceType.online,
    );
    expect(
      effectiveSyncPresence(PresenceType.online, active: false),
      PresenceType.offline,
    );
    expect(
      effectiveSyncPresence(PresenceType.online, active: true, idle: true),
      PresenceType.unavailable,
    );
    expect(
      effectiveSyncPresence(PresenceType.unavailable, active: true),
      PresenceType.unavailable,
    );
    // Manually invisible accounts never leak a higher presence.
    expect(
      effectiveSyncPresence(PresenceType.offline, active: true),
      PresenceType.offline,
    );
    expect(
      effectiveSyncPresence(PresenceType.offline, active: false),
      PresenceType.offline,
    );
  });

  test('sync presence follows account switches and chosen presence', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await AppSettings.load();
    final first = await buildFakeClient();
    final second = await buildFakeClient(name: 'Protea-2');
    addTearDown(() => first.dispose(closeDatabase: true));
    addTearDown(() => second.dispose(closeDatabase: true));

    final manager = ClientManager.forTesting(prefs, [first, second]);
    final service = PresenceService(manager, settings)..init();
    addTearDown(service.dispose);

    expect(manager.activeClient, first);
    expect(first.syncPresence, PresenceType.online);
    expect(second.syncPresence, PresenceType.offline);

    manager.setActive(second);
    expect(first.syncPresence, PresenceType.offline);
    expect(second.syncPresence, PresenceType.online);

    // An account set to invisible stays invisible, active or not.
    await settings.setPresenceFor(first.clientName, PresenceType.offline);
    expect(first.syncPresence, PresenceType.offline);
    manager.setActive(first);
    expect(first.syncPresence, PresenceType.offline);
    expect(second.syncPresence, PresenceType.offline);
  });

  test('activity brings the account straight back from auto-away', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await AppSettings.load();
    final client = await buildFakeClient();
    addTearDown(() => client.dispose(closeDatabase: true));

    final manager = ClientManager.forTesting(prefs, [client]);
    // Idle the moment the check runs, instead of waiting out ten minutes.
    final service = PresenceService(
      manager,
      settings,
      idleThreshold: Duration.zero,
    )..init();
    addTearDown(service.dispose);

    expect(client.syncPresence, PresenceType.online);

    service.checkIdle();
    expect(client.syncPresence, PresenceType.unavailable);

    // Any input — a mouse move over the window is enough — comes back at
    // once, without waiting for a view to load or a sync to come round.
    service.notifyActivity();
    expect(client.syncPresence, PresenceType.online);

    // Auto-away off means the idle check never takes the account away.
    await settings.setAutoAway(false);
    service.checkIdle();
    expect(client.syncPresence, PresenceType.online);
  });
}
