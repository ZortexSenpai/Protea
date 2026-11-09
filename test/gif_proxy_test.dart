// Sending a GIF through the proxy replaces the download-and-upload with an
// mxc URI the proxy resolves: `mxc://<proxy>/klipy_<base64url of the CDN
// path>`. The encoding has to match the proxy exactly or the media 404s for
// everyone, so the fixture below is the one from Soliditas' own README.
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/gif_proxy.dart';

const _path = 'ffd4ac143e6335ac68951b787d3c1902/e8/3a/5LM0jRpL.gif';
const _url = 'https://static.klipy.com/ii/$_path';

void main() {
  test('a klipy CDN url becomes the proxy mxc uri', () {
    expect(
      gifProxyMxcUrl(_url, defaultGifProxyServer),
      'mxc://gifs.sable.moe/klipy_'
      'ZmZkNGFjMTQzZTYzMzVhYzY4OTUxYjc4N2QzYzE5MDIvZTgvM2EvNUxNMGpScEwuZ2lm',
    );
  });

  test('the proxy server is configurable and trimmed', () {
    expect(
      gifProxyMxcUrl(_url, '  gifs.example.org '),
      startsWith('mxc://gifs.example.org/klipy_'),
    );
    expect(gifProxyMxcUrl(_url, '   '), isNull);
  });

  test('anything the proxy cannot resolve is refused', () {
    // Only Klipy's CDN, over plain https, on the path the proxy rebuilds.
    expect(gifProxyMxcUrl('http://static.klipy.com/ii/$_path', 'p'), isNull);
    expect(gifProxyMxcUrl('https://evil.example/ii/$_path', 'p'), isNull);
    expect(gifProxyMxcUrl('https://static.klipy.com:8443/ii/x', 'p'), isNull);
    expect(gifProxyMxcUrl('https://u:p@static.klipy.com/ii/x', 'p'), isNull);
    expect(gifProxyMxcUrl('https://static.klipy.com/other/x', 'p'), isNull);
    expect(gifProxyMxcUrl('https://static.klipy.com/ii/', 'p'), isNull);
    // A path that would not survive being rebuilt by the proxy verbatim.
    expect(gifProxyMxcUrl('https://static.klipy.com/ii/a b.gif', 'p'), isNull);
    expect(gifProxyMxcUrl('not a url at all', 'p'), isNull);
  });

  test('the event carries the dimensions, since nothing measures the file', () {
    expect(
      gifProxyImageContent(
        name: 'cat.gif',
        mxcUrl: 'mxc://gifs.sable.moe/klipy_abc',
        width: 480,
        height: 270,
        size: 1234,
      ),
      {
        'msgtype': 'm.image',
        'body': 'cat.gif',
        'url': 'mxc://gifs.sable.moe/klipy_abc',
        'info': {'mimetype': 'image/gif', 'w': 480, 'h': 270, 'size': 1234},
      },
    );
    // Klipy doesn't always report them; the keys are left out rather than
    // sent as nulls, and no `filename` is set so the body isn't a caption.
    expect(gifProxyImageContent(name: 'cat.gif', mxcUrl: 'mxc://p/klipy_abc'), {
      'msgtype': 'm.image',
      'body': 'cat.gif',
      'url': 'mxc://p/klipy_abc',
      'info': {'mimetype': 'image/gif'},
    });
  });
}
