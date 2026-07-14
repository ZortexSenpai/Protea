import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../client_manager.dart';
import '../pages/login_page.dart';
import 'mxc_avatar.dart';

/// Shows all logged-in accounts, switches on tap and offers adding another
/// account.
Future<void> showAccountSwitcher(BuildContext context, ClientManager manager) =>
    showDialog(
      context: context,
      builder: (_) => AccountSwitcherDialog(manager: manager),
    );

class AccountSwitcherDialog extends StatelessWidget {
  const AccountSwitcherDialog({super.key, required this.manager});

  final ClientManager manager;

  Future<void> _addAccount(BuildContext context) async {
    final navigator = Navigator.of(context);
    final client = await manager.prepareAdditionalClient();
    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => LoginPage(client: client)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Accounts'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 360,
        child: ListenableBuilder(
          listenable: manager,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final client in manager.loggedInClients)
                _AccountTile(
                  client: client,
                  active: manager.activeClient == client,
                  onTap: () {
                    manager.setActive(client);
                    Navigator.of(context).pop();
                  },
                ),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Add account'),
                onTap: () => _addAccount(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.client,
    required this.active,
    required this.onTap,
  });

  final Client client;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final userId = client.userID ?? '?';
    return FutureBuilder<Profile>(
      future: client.fetchOwnProfile(),
      builder: (context, snapshot) => ListTile(
        leading: MxcAvatar(
          client: client,
          name: snapshot.data?.displayName ?? userId,
          avatarUrl: snapshot.data?.avatarUrl,
          radius: 18,
        ),
        title: Text(
          snapshot.data?.displayName ?? userId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(userId, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: active
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
