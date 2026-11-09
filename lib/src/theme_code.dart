import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'themes.dart';

/// Prefix identifying a Protea palette code, and the version of the payload
/// that follows it. A code carries both palettes, light first, six colors
/// each, three bytes per color — alpha is not part of a palette.
const _codePrefix = 'protea-theme-1.';
const _colorsPerPalette = 6;
const _bytesPerColor = 3;

/// A light/dark pair of custom palettes, as shared by a palette code.
typedef PaletteCodePair = ({CustomPalette light, CustomPalette dark});

/// Encodes both palettes into a code that can be pasted into another
/// Protea. Short enough to send in a message.
String encodePaletteCode(CustomPalette light, CustomPalette dark) {
  final bytes = Uint8List(_colorsPerPalette * 2 * _bytesPerColor);
  var at = 0;
  for (final color in [...light.colors, ...dark.colors]) {
    bytes[at++] = (color.toARGB32() >> 16) & 0xFF;
    bytes[at++] = (color.toARGB32() >> 8) & 0xFF;
    bytes[at++] = color.toARGB32() & 0xFF;
  }
  return '$_codePrefix${base64Url.encode(bytes).replaceAll('=', '')}';
}

/// Reads a code produced by [encodePaletteCode], or null when [code] isn't
/// one — a wrong prefix, characters base64url doesn't use, or the wrong
/// number of colors. Surrounding whitespace is ignored, so a code pasted
/// from a message works.
PaletteCodePair? decodePaletteCode(String code) {
  final trimmed = code.trim();
  if (!trimmed.startsWith(_codePrefix)) return null;
  final payload = trimmed.substring(_codePrefix.length);
  final padded = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
  final Uint8List bytes;
  try {
    bytes = base64Url.decode(padded);
  } on FormatException {
    return null;
  }
  if (bytes.length != _colorsPerPalette * 2 * _bytesPerColor) return null;
  final colors = [
    for (var at = 0; at < bytes.length; at += _bytesPerColor)
      Color.fromARGB(0xFF, bytes[at], bytes[at + 1], bytes[at + 2]),
  ];
  final light = CustomPalette.fromColors(colors.sublist(0, _colorsPerPalette));
  final dark = CustomPalette.fromColors(colors.sublist(_colorsPerPalette));
  return light == null || dark == null ? null : (light: light, dark: dark);
}
