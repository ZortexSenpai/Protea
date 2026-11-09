import 'dart:convert';

/// Sable's public GIF proxy — the default for [AppSettings.gifProxyServer].
const defaultGifProxyServer = 'gifs.sable.moe';

/// Klipy CDN paths are hex directories and a file name. Anything outside that
/// would have to survive percent-encoding on the way through the proxy, so
/// such a URL is sent the normal way instead.
final _safePayload = RegExp(r'^[A-Za-z0-9._\-/]+$');

/// The `mxc://` URI that serves [mediaUrl] through the GIF proxy at
/// [proxyServer], or null when the URL is not one the proxy can resolve.
///
/// The proxy (Sable's Soliditas) answers federation media requests: the media
/// id is `<provider>_<base64url payload>`, and the proxy redirects the
/// requesting homeserver to the provider's CDN. Sending that URI in place of
/// an upload means the GIF never passes through this client or the user's
/// homeserver — every viewer's homeserver fetches it on demand instead.
///
/// Klipy is the only provider Protea's picker uses; its payload is the CDN
/// path that the proxy appends to `https://static.klipy.com/ii/`.
String? gifProxyMxcUrl(String mediaUrl, String proxyServer) {
  final server = proxyServer.trim();
  final url = Uri.tryParse(mediaUrl);
  if (server.isEmpty || url == null) return null;
  if (url.scheme != 'https' ||
      url.host != 'static.klipy.com' ||
      url.hasPort ||
      url.userInfo.isNotEmpty ||
      !url.path.startsWith('/ii/')) {
    return null;
  }
  final payload = url.path.substring('/ii/'.length);
  if (payload.isEmpty || !_safePayload.hasMatch(payload)) return null;
  return 'mxc://$server/klipy_${_base64Url(payload)}';
}

/// The `m.image` content for a GIF served by the proxy, as Sable sends it:
/// no `file` (the media is public on the CDN) and no `filename`, so the body
/// stays the GIF's name rather than reading as a caption.
Map<String, Object?> gifProxyImageContent({
  required String name,
  required String mxcUrl,
  int? width,
  int? height,
  int? size,
}) => {
  'msgtype': 'm.image',
  'body': name,
  'url': mxcUrl,
  'info': {'mimetype': 'image/gif', 'w': ?width, 'h': ?height, 'size': ?size},
};

/// base64url without padding, the form the proxy decodes.
String _base64Url(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');
