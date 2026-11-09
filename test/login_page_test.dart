import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';

import 'package:protea/src/l10n.dart';
import 'package:protea/src/pages/login_page.dart';

import 'fake_client.dart';

/// A logged-out client as ClientManager hands it to the login page.
Future<Client> _buildLoggedOutClient() async => Client(
  'Protea',
  httpClient: FakeMatrixApi(),
  database: await openFakeDatabase(),
  supportedLoginTypes: {AuthenticationTypes.password, AuthenticationTypes.sso},
);

/// Lets FakeMatrixApi requests complete and the step transition finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

int _versionRequests() => FakeMatrixApi.calledEndpoints.keys
    .where((endpoint) => endpoint.contains('/client/versions'))
    .length;

Future<Client> _pumpLoginPage(WidgetTester tester) async {
  final client = (await tester.runAsync(_buildLoggedOutClient))!;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginPage(client: client),
    ),
  );
  await tester.pump();
  return client;
}

Future<void> _tearDown(WidgetTester tester, Client client) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 31));
  await tester.runAsync(() => client.dispose(closeDatabase: false));
}

Finder get _homeserverField => find.widgetWithText(TextField, 'Homeserver');

void main() {
  testWidgets('asks for the homeserver first and checks it only on submit', (
    tester,
  ) async {
    final client = await _pumpLoginPage(tester);

    // Step 1: only the homeserver field; no sign-in fields yet.
    expect(_homeserverField, findsOneWidget);
    expect(find.text('Username'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);

    // Typing does not query the server.
    await tester.enterText(_homeserverField, 'fakeserver.notexisting');
    await _settle(tester);
    expect(_versionRequests(), 0);
    expect(find.text('Username'), findsNothing);

    // Step 2 after submitting: the password form for this server.
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(_versionRequests(), 1);
    expect(client.homeserver, Uri.parse('https://fakeserver.notexisting'));
    expect(_homeserverField, findsNothing);
    expect(find.text('fakeserver.notexisting'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.textContaining('SSO'), findsNothing);

    // Going back keeps the entered server editable.
    await tester.tap(find.byTooltip('Change homeserver'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_homeserverField, findsOneWidget);
    expect(find.text('fakeserver.notexisting'), findsOneWidget);
    expect(find.text('Username'), findsNothing);

    await _tearDown(tester, client);
  });

  testWidgets('shows only the SSO providers of an SSO-only server', (
    tester,
  ) async {
    final client = await _pumpLoginPage(tester);
    FakeMatrixApi.currentApi!.api['GET']!['/client/v3/login'] = (_) => {
      'flows': [
        {
          'type': 'm.login.sso',
          'identity_providers': [
            {'id': 'oidc-authentik', 'name': 'authentik'},
          ],
        },
      ],
    };

    await tester.enterText(_homeserverField, 'fakeserver.notexisting');
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('Sign in with authentik'), findsOneWidget);
    expect(find.text('Username'), findsNothing);
    expect(find.text('Password'), findsNothing);

    await _tearDown(tester, client);
  });

  testWidgets('stays on the homeserver step when the server is unreachable', (
    tester,
  ) async {
    final client = await _pumpLoginPage(tester);

    await tester.enterText(_homeserverField, 'unknown.example');
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(_homeserverField, findsOneWidget);
    expect(find.textContaining('Could not connect'), findsOneWidget);
    expect(find.text('Username'), findsNothing);

    // Editing the address clears the error.
    await tester.enterText(_homeserverField, 'fakeserver.notexisting');
    await tester.pump();
    expect(find.textContaining('Could not connect'), findsNothing);

    await _tearDown(tester, client);
  });
}
