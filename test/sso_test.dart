import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';

import 'package:protea/src/sso.dart';

void main() {
  group('ssoProvidersFromFlows', () {
    test('returns empty list when the homeserver has no SSO flow', () {
      final flows = [LoginFlow(type: AuthenticationTypes.password)];
      expect(ssoProvidersFromFlows(flows), isEmpty);
    });

    test('returns a single generic provider for plain m.login.sso', () {
      final flows = [
        LoginFlow(type: AuthenticationTypes.password),
        LoginFlow(type: AuthenticationTypes.sso),
      ];
      final providers = ssoProvidersFromFlows(flows);
      expect(providers, hasLength(1));
      expect(providers.single.id, isNull);
    });

    test('parses MSC2858 identity providers', () {
      final flows = [
        LoginFlow.fromJson({
          'type': 'm.login.sso',
          'identity_providers': [
            {'id': 'google', 'name': 'Google'},
            {'id': 'github', 'name': 'GitHub'},
          ],
        }),
      ];
      final providers = ssoProvidersFromFlows(flows);
      expect(providers, hasLength(2));
      expect(providers.first.id, 'google');
      expect(providers.first.name, 'Google');
      expect(providers.last.id, 'github');
    });
  });

  group('waitForLoginToken', () {
    test('completes with the loginToken from the callback request', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tokenFuture = waitForLoginToken(server);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(
          'http://localhost:${server.port}/callback?loginToken=syt_secret',
        ),
      );
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(await tokenFuture, 'syt_secret');
      expect(body, contains('Login successful'));

      client.close();
      await server.close(force: true);
    });

    test('times out when no callback arrives', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      expect(
        () => waitForLoginToken(
          server,
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<Exception>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await server.close(force: true);
    });
  });
}
