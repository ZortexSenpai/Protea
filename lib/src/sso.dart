import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher.dart';

/// The custom URL scheme used to return from the browser on Android and iOS.
/// Must match the intent-filter in AndroidManifest.xml and the
/// CFBundleURLSchemes entry in ios/Runner/Info.plist.
const ssoCallbackScheme = 'protea';

const _ssoTimeout = Duration(minutes: 5);

/// One entry of an `m.login.sso` flow's `identity_providers` list (MSC2858).
/// A homeserver without that list (e.g. matrix.org) still supports SSO
/// through a single provider with [id] == null.
class SsoIdentityProvider {
  const SsoIdentityProvider({this.id, required this.name});

  final String? id;
  final String name;
}

/// Extracts the SSO identity providers from the login flows returned by
/// [Client.checkHomeserver]. Returns an empty list if the homeserver does
/// not support SSO login at all.
List<SsoIdentityProvider> ssoProvidersFromFlows(List<LoginFlow> flows) {
  final ssoFlow = flows.where((f) => f.type == AuthenticationTypes.sso);
  if (ssoFlow.isEmpty) return [];
  final rawProviders =
      ssoFlow.first.additionalProperties['identity_providers'];
  if (rawProviders is List) {
    final providers = rawProviders
        .whereType<Map>()
        .map(
          (p) => SsoIdentityProvider(
            id: p['id'] as String?,
            name: p['name'] as String? ?? p['id'] as String? ?? 'SSO',
          ),
        )
        .toList();
    if (providers.isNotEmpty) return providers;
  }
  return [const SsoIdentityProvider(id: null, name: 'SSO')];
}

/// Performs a complete single-sign-on login: opens the system browser on the
/// homeserver's SSO redirect endpoint, waits for the redirect back with a
/// `loginToken` and exchanges it for an access token.
///
/// [Client.checkHomeserver] must have been called before.
Future<void> ssoLogin(Client client, {String? idpId}) async {
  final homeserver = client.homeserver;
  if (homeserver == null) {
    throw Exception('No homeserver set. Call checkHomeserver first.');
  }

  final useLocalhostCallback =
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  HttpServer? server;
  final String redirectUrl;
  if (useLocalhostCallback) {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    redirectUrl = 'http://localhost:${server.port}/callback';
  } else {
    redirectUrl = '$ssoCallbackScheme://login';
  }

  try {
    final idpPath = idpId == null ? '' : '/${Uri.encodeComponent(idpId)}';
    final ssoUrl = Uri.parse(
      '$homeserver/_matrix/client/v3/login/sso/redirect$idpPath'
      '?redirectUrl=${Uri.encodeQueryComponent(redirectUrl)}',
    );

    if (!await launchUrl(ssoUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open the browser for SSO login.');
    }

    final token = server != null
        ? await waitForLoginToken(server)
        : await _waitForAppLink();

    await client.login(
      AuthenticationTypes.token,
      token: token,
      initialDeviceDisplayName: 'Protea',
    );
  } finally {
    await server?.close(force: true);
  }
}

/// Waits for the browser to hit the local callback server with a
/// `loginToken` query parameter and returns that token.
@visibleForTesting
Future<String> waitForLoginToken(
  HttpServer server, {
  Duration timeout = _ssoTimeout,
}) async {
  final completer = Completer<String>();
  final subscription = server.listen((request) async {
    final token = request.uri.queryParameters['loginToken'];
    request.response.headers.contentType = ContentType.html;
    request.response.write(
      token != null
          ? '<html><body style="font-family: sans-serif; text-align: center; '
              'margin-top: 4em"><h2>Login successful</h2>'
              '<p>You can close this window and return to Protea.</p>'
              '</body></html>'
          : '<html><body>Missing loginToken parameter.</body></html>',
    );
    await request.response.close();
    if (token != null && !completer.isCompleted) {
      completer.complete(token);
    }
  });
  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException('SSO login timed out.'),
    );
  } finally {
    await subscription.cancel();
  }
}

/// Waits for the `protea://login?loginToken=...` deep link on Android/iOS.
Future<String> _waitForAppLink() async {
  final uri = await AppLinks().uriLinkStream
      .firstWhere(
        (uri) =>
            uri.scheme == ssoCallbackScheme &&
            uri.queryParameters['loginToken'] != null,
      )
      .timeout(
        _ssoTimeout,
        onTimeout: () => throw TimeoutException('SSO login timed out.'),
      );
  return uri.queryParameters['loginToken']!;
}
