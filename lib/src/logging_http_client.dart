import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

/// Wraps the SDK's HTTP client to log the status code and body of failed
/// homeserver requests.
///
/// The generated Matrix API throws a bare `Exception('http error response')`
/// whenever a non-2xx body is not parseable Matrix JSON, discarding both the
/// status code and the body. That turns an infrastructure failure (a reverse
/// proxy 502, a CDN block page, a captive portal) into an error nobody can
/// act on. Logging the response here keeps the diagnosis in reach without
/// forking the SDK.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient(this._inner);

  final http.Client _inner;

  /// How much of an error body to log. Enough to identify an HTML error page
  /// or a proxy banner without dumping a whole document into the log.
  static const _maxLoggedBody = 512;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode < 400) return response;

    // The stream can only be read once, so buffer it and hand back an
    // equivalent response for the SDK to consume.
    final body = await response.stream.toBytes();

    String snippet;
    try {
      snippet = utf8.decode(body);
    } catch (_) {
      snippet = '<${body.length} bytes of non-UTF-8 data>';
    }
    if (snippet.length > _maxLoggedBody) {
      snippet =
          '${snippet.substring(0, _maxLoggedBody)}… '
          '(${body.length} bytes total)';
    }

    Logs().w(
      'HTTP ${response.statusCode} from ${request.method} ${request.url}\n'
      'content-type: ${response.headers['content-type'] ?? '<none>'}\n'
      'body: $snippet',
    );

    return http.StreamedResponse(
      Stream.value(body),
      response.statusCode,
      contentLength: body.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
