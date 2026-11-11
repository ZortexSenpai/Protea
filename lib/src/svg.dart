import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG support. The engine's image codecs only decode bitmaps (JPEG, PNG,
/// GIF, WebP, BMP), so [Image.memory] fails on SVG attachments with
/// "Invalid image data"; these are drawn with flutter_svg instead.

/// How far into the file the `<svg` root element is looked for; XML
/// declarations, comments and doctypes of editor exports come before it.
const _sniffLength = 4096;

final _sniffed = Expando<bool>('looksLikeSvg');

/// Whether [bytes] are an SVG document.
///
/// Decided on the content, not the event's mimetype: an SVG event's
/// thumbnail is a PNG, and other clients send SVGs with a missing or
/// generic mimetype. Memoized per buffer, since widgets ask on every build.
bool looksLikeSvg(Uint8List bytes) => _sniffed[bytes] ??= _sniff(bytes);

bool _sniff(Uint8List bytes) {
  var start = 0;
  // UTF-8 byte order mark.
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  while (start < bytes.length && _isXmlSpace(bytes[start])) {
    start++;
  }
  // Every XML document starts with '<'; no bitmap format does.
  if (start >= bytes.length || bytes[start] != 0x3C) return false;
  final head = latin1.decode(
    Uint8List.sublistView(bytes, start, min(bytes.length, _sniffLength)),
  );
  return head.contains('<svg');
}

bool _isXmlSpace(int byte) =>
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D;

/// [Image.memory] that also draws SVG documents.
///
/// [cacheWidth] only applies to bitmaps; an SVG is drawn as vectors at
/// whatever size it is laid out. [errorBuilder] replaces an undecodable
/// image of either kind.
Widget memoryImage(
  Uint8List bytes, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  AlignmentGeometry alignment = Alignment.center,
  int? cacheWidth,
  WidgetBuilder? errorBuilder,
}) {
  if (looksLikeSvg(bytes)) {
    return SvgPicture.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: errorBuilder == null
          ? null
          : (context, _, _) => errorBuilder(context),
    );
  }
  return Image.memory(
    bytes,
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    cacheWidth: cacheWidth,
    errorBuilder: errorBuilder == null
        ? null
        : (context, _, _) => errorBuilder(context),
  );
}

/// An SVG drawn into a PNG.
typedef SvgRaster = ({
  Uint8List png,
  int width,
  int height,

  /// The document's own size (its width/height, else its viewBox).
  int intrinsicWidth,
  int intrinsicHeight,
});

/// Draws the SVG [bytes] into a PNG that fits within [maxExtent] pixels,
/// never scaled up beyond the document's own size. Returns null when the
/// document cannot be parsed or declares no usable size.
Future<SvgRaster?> rasterizeSvg(
  Uint8List bytes, {
  required double maxExtent,
}) async {
  final PictureInfo info;
  try {
    info = await vg.loadPicture(SvgBytesLoader(bytes), null);
  } catch (_) {
    return null;
  }
  try {
    final size = info.size;
    if (!size.isFinite || size.isEmpty) return null;
    final scale = min(
      1.0,
      min(maxExtent / size.width, maxExtent / size.height),
    );
    final width = max(1, (size.width * scale).round());
    final height = max(1, (size.height * scale).round());
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..scale(width / size.width, height / size.height)
      ..drawPicture(info.picture);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    return (
      png: data.buffer.asUint8List(),
      width: width,
      height: height,
      intrinsicWidth: max(1, size.width.round()),
      intrinsicHeight: max(1, size.height.round()),
    );
  } finally {
    info.picture.dispose();
  }
}
