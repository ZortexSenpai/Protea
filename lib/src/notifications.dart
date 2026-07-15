import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';

import 'client_manager.dart';
import 'pages/room_page.dart';
import 'settings.dart';

/// Shows desktop notifications for incoming messages (as selected by the
/// account's push rules) of all logged-in accounts while the window is not
/// focused.
class NotificationService with WidgetsBindingObserver {
  NotificationService(this.manager, {this.navigatorKey, this.settings});

  final ClientManager manager;
  final GlobalKey<NavigatorState>? navigatorKey;
  final AppSettings? settings;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _listening = <Client>{};
  final _subscriptions = <StreamSubscription<Event>>[];
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  static const _notifiableTypes = {
    EventTypes.Message,
    EventTypes.Encrypted,
    EventTypes.Sticker,
  };

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    try {
      // Permissions are NOT requested during initialize: the request blocks
      // until the user answers the system prompt (or forever when the prompt
      // cannot be shown), so it must never gate anything else.
      await _plugin.initialize(
        settings: const InitializationSettings(
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      unawaited(
        _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true),
      );
    } catch (e, s) {
      Logs().w('Failed to initialize desktop notifications', e, s);
    }
    _listenAll();
    manager.addListener(_listenAll);
  }

  void _listenAll() {
    for (final client in manager.clients) {
      if (!_listening.add(client)) continue;
      _subscriptions.add(
        client.onNotification.stream.listen(
          (event) => _showNotification(client, event),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  /// Opens the room a tapped notification belongs to. The payload is
  /// `clientName|roomId`.
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    final navigator = navigatorKey?.currentState;
    if (payload == null || navigator == null) return;
    final separator = payload.indexOf('|');
    if (separator == -1) return;
    final clientName = payload.substring(0, separator);
    final roomId = payload.substring(separator + 1);
    for (final client in manager.clients) {
      if (client.clientName != clientName) continue;
      final room = client.getRoomById(roomId);
      if (room == null) return;
      if (manager.activeClient != client) manager.setActive(client);
      navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
      return;
    }
  }

  Future<void> _showNotification(Client client, Event event) async {
    if (!(settings?.desktopNotifications ?? true)) return;
    // On desktop the lifecycle reflects window focus: only notify when the
    // app is in the background.
    if (_lifecycle == AppLifecycleState.resumed) return;
    if (event.senderId == client.userID) return;
    if (!_notifiableTypes.contains(event.type)) return;
    final room = event.room;
    final body = event.calcLocalizedBodyFallback(
      const MatrixDefaultLocalizations(),
      hideReply: true,
      plaintextBody: true,
      removeMarkdown: true,
      withSenderNamePrefix: !room.isDirectChat,
    );
    try {
      await _plugin.show(
        id: event.eventId.hashCode,
        title: room.getLocalizedDisplayname(),
        body: body,
        notificationDetails: NotificationDetails(
          macOS: DarwinNotificationDetails(
            presentSound: settings?.notificationSounds ?? true,
          ),
        ),
        payload: '${client.clientName}|${room.id}',
      );
    } catch (_) {
      // Notifications are best-effort (permission may have been denied).
    }
  }
}
