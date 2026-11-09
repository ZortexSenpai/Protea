import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'matrix.dart';
import 'settings.dart';
import 'widgets/user_banner.dart';

/// Owns one Matrix [Client] per account, persists the account list across
/// restarts and tracks which account is currently shown.
class ClientManager extends ChangeNotifier {
  ClientManager._(this._prefs);

  /// A manager around pre-built clients, for widget tests.
  @visibleForTesting
  ClientManager.forTesting(this._prefs, List<Client> clients) {
    clients.forEach(_register);
    _activeClient = clients.firstWhere(
      (client) => client.isLogged(),
      orElse: () => clients.first,
    );
  }

  static const _accountsKey = 'accounts';
  static const _activeAccountKey = 'activeAccount';

  final SharedPreferences _prefs;
  final List<Client> _clients = [];
  final List<StreamSubscription<CachedPresence>> _profileHintSubscriptions = [];
  Client? _activeClient;

  static Future<ClientManager> load(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final manager = ClientManager._(prefs);
    // 'Protea' is the pre-multi-account client name, so existing sessions
    // are picked up as the first account.
    final names = prefs.getStringList(_accountsKey) ?? ['Protea'];
    final activeName = prefs.getString(_activeAccountKey) ?? names.first;
    for (final name in names) {
      manager._register(
        await buildMatrixClient(
          name: name,
          // The right presence from the very first sync request on; the
          // PresenceService keeps it up to date from here.
          syncPresence: effectiveSyncPresence(
            settings.presenceFor(name),
            active: name == activeName,
          ),
        ),
      );
    }
    final loggedIn = manager.loggedInClients;
    manager._activeClient = loggedIn.isEmpty ? null : loggedIn.first;
    for (final client in loggedIn) {
      if (client.clientName == activeName) {
        manager._activeClient = client;
        break;
      }
    }
    return manager;
  }

  List<Client> get clients => List.unmodifiable(_clients);

  List<Client> get loggedInClients =>
      _clients.where((client) => client.isLogged()).toList();

  /// The account currently shown, or null when no account is logged in.
  Client? get activeClient => _activeClient;

  /// A client without a session for the login screen. Guaranteed to exist
  /// whenever [activeClient] is null (first run or after the last logout).
  Client get loginCandidate =>
      _clients.firstWhere((client) => !client.isLogged());

  /// Switches the visible account.
  void setActive(Client client) {
    if (!client.isLogged() || _activeClient == client) return;
    _activeClient = client;
    _prefs.setString(_activeAccountKey, client.clientName);
    notifyListeners();
  }

  /// Returns a client without a session to log an additional account in
  /// with, reusing an idle one when possible.
  Future<Client> prepareAdditionalClient() async {
    for (final client in _clients) {
      if (!client.isLogged()) return client;
    }
    final names = _clients.map((client) => client.clientName).toSet();
    var index = 2;
    while (names.contains('Protea-$index')) {
      index++;
    }
    final client = await buildMatrixClient(name: 'Protea-$index');
    _register(client);
    return client;
  }

  void _register(Client client) {
    _clients.add(client);
    // Status texts live in an extended profile field, which never travels
    // over sync; a presence update is the only hint one changed. Watching
    // from here rather than from a widget means the caches are dropped even
    // while nothing showing that user is on screen.
    _profileHintSubscriptions.add(watchProfileHints(client));
    client.onLoginStateChanged.stream.listen((state) {
      if (state == LoginState.loggedIn) {
        _activeClient = client;
        _prefs.setString(_activeAccountKey, client.clientName);
      } else if (state == LoginState.loggedOut && _activeClient == client) {
        Client? next;
        for (final other in _clients) {
          if (other != client && other.isLogged()) {
            next = other;
            break;
          }
        }
        _activeClient = next;
        if (next != null) {
          _prefs.setString(_activeAccountKey, next.clientName);
        }
      }
      _persistAccounts();
      notifyListeners();
    });
  }

  void _persistAccounts() {
    final names = loggedInClients.map((client) => client.clientName).toList();
    _prefs.setStringList(_accountsKey, names.isEmpty ? ['Protea'] : names);
  }

  @override
  void dispose() {
    for (final subscription in _profileHintSubscriptions) {
      subscription.cancel();
    }
    _profileHintSubscriptions.clear();
    super.dispose();
  }
}
