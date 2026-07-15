import 'package:flutter/material.dart';

import 'settings.dart';

/// Full color schemes for the selectable app themes. Each non-Material
/// theme is built from its palette's accent seed and then overridden with
/// the palette's canonical background/surface/text colors, so the whole
/// Material role set stays populated and harmonious.
ColorScheme schemeFor(
  AppTheme theme,
  AppThemeColor seed,
  Brightness brightness,
) {
  final dark = brightness == Brightness.dark;
  return switch (theme) {
    AppTheme.material => ColorScheme.fromSeed(
      seedColor: seed.seed,
      brightness: brightness,
    ),
    AppTheme.catppuccin => dark ? _catppuccinMocha : _catppuccinLatte,
    AppTheme.nord => dark ? _nordDark : _nordLight,
    AppTheme.dracula => dark ? _dracula : _draculaLight,
    AppTheme.gruvbox => dark ? _gruvboxDark : _gruvboxLight,
    AppTheme.tokyoNight => dark ? _tokyoNight : _tokyoNightDay,
  };
}

ColorScheme _build(
  Brightness brightness,
  Color accent, {
  required Color surface,
  required Color lowest,
  required Color low,
  required Color container,
  required Color high,
  required Color highest,
  required Color onSurface,
  required Color onSurfaceVariant,
  required Color outline,
  Color? primary,
  Color? onPrimary,
}) {
  final base = ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
  return base.copyWith(
    primary: primary ?? accent,
    onPrimary: onPrimary,
    surface: surface,
    surfaceContainerLowest: lowest,
    surfaceContainerLow: low,
    surfaceContainer: container,
    surfaceContainerHigh: high,
    surfaceContainerHighest: highest,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: highest,
    surfaceTint: Colors.transparent,
  );
}

// ---- Catppuccin (Mocha / Latte) -------------------------------------------

final _catppuccinMocha = _build(
  Brightness.dark,
  const Color(0xFFCBA6F7), // mauve
  surface: const Color(0xFF1E1E2E), // base
  lowest: const Color(0xFF11111B), // crust
  low: const Color(0xFF181825), // mantle
  container: const Color(0xFF313244), // surface0
  high: const Color(0xFF45475A), // surface1
  highest: const Color(0xFF585B70), // surface2
  onSurface: const Color(0xFFCDD6F4), // text
  onSurfaceVariant: const Color(0xFFA6ADC8), // subtext0
  outline: const Color(0xFF7F849C), // overlay1
  onPrimary: const Color(0xFF11111B),
);

final _catppuccinLatte = _build(
  Brightness.light,
  const Color(0xFF8839EF), // mauve
  surface: const Color(0xFFEFF1F5), // base
  lowest: const Color(0xFFFFFFFF),
  low: const Color(0xFFE6E9EF), // mantle
  container: const Color(0xFFDCE0E8), // crust
  high: const Color(0xFFCCD0DA), // surface0
  highest: const Color(0xFFBCC0CC), // surface1
  onSurface: const Color(0xFF4C4F69), // text
  onSurfaceVariant: const Color(0xFF6C6F85), // subtext0
  outline: const Color(0xFF8C8FA1), // overlay1
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- Nord ------------------------------------------------------------------

final _nordDark = _build(
  Brightness.dark,
  const Color(0xFF88C0D0), // frost
  surface: const Color(0xFF2E3440), // nord0
  lowest: const Color(0xFF272C36),
  low: const Color(0xFF2B303B),
  container: const Color(0xFF3B4252), // nord1
  high: const Color(0xFF434C5E), // nord2
  highest: const Color(0xFF4C566A), // nord3
  onSurface: const Color(0xFFECEFF4), // nord6
  onSurfaceVariant: const Color(0xFFD8DEE9), // nord4
  outline: const Color(0xFF616E88),
  onPrimary: const Color(0xFF2E3440),
);

final _nordLight = _build(
  Brightness.light,
  const Color(0xFF5E81AC), // nord10
  surface: const Color(0xFFECEFF4), // nord6
  lowest: const Color(0xFFFFFFFF),
  low: const Color(0xFFE5E9F0), // nord5
  container: const Color(0xFFD8DEE9), // nord4
  high: const Color(0xFFCDD5E1),
  highest: const Color(0xFFC2CBD9),
  onSurface: const Color(0xFF2E3440),
  onSurfaceVariant: const Color(0xFF4C566A),
  outline: const Color(0xFF7B88A1),
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- Dracula ---------------------------------------------------------------

final _dracula = _build(
  Brightness.dark,
  const Color(0xFFBD93F9), // purple
  surface: const Color(0xFF282A36), // background
  lowest: const Color(0xFF1E2029),
  low: const Color(0xFF232530),
  container: const Color(0xFF2C2E3A),
  high: const Color(0xFF363948),
  highest: const Color(0xFF44475A), // current line
  onSurface: const Color(0xFFF8F8F2), // foreground
  onSurfaceVariant: const Color(0xFFB8BCCF),
  outline: const Color(0xFF6272A4), // comment
  onPrimary: const Color(0xFF1E2029),
);

/// Dracula has no official light palette; a seed-derived scheme keeps the
/// purple identity in light mode.
final _draculaLight = ColorScheme.fromSeed(seedColor: const Color(0xFFBD93F9));

// ---- Gruvbox ---------------------------------------------------------------

final _gruvboxDark = _build(
  Brightness.dark,
  const Color(0xFFFE8019), // orange
  surface: const Color(0xFF282828), // bg
  lowest: const Color(0xFF1D2021), // bg0_h
  low: const Color(0xFF232323),
  container: const Color(0xFF3C3836), // bg1
  high: const Color(0xFF504945), // bg2
  highest: const Color(0xFF665C54), // bg3
  onSurface: const Color(0xFFEBDBB2), // fg
  onSurfaceVariant: const Color(0xFFBDAE93), // fg3
  outline: const Color(0xFF928374), // gray
  onPrimary: const Color(0xFF1D2021),
);

final _gruvboxLight = _build(
  Brightness.light,
  const Color(0xFFD65D0E), // orange
  surface: const Color(0xFFFBF1C7), // bg
  lowest: const Color(0xFFFFFDF0),
  low: const Color(0xFFF2E5BC), // bg0_s
  container: const Color(0xFFEBDBB2), // bg1
  high: const Color(0xFFD5C4A1), // bg2
  highest: const Color(0xFFBDAE93), // bg3
  onSurface: const Color(0xFF3C3836), // fg
  onSurfaceVariant: const Color(0xFF665C54),
  outline: const Color(0xFF928374),
  onPrimary: const Color(0xFFFFFDF0),
);

// ---- Tokyo Night -----------------------------------------------------------

final _tokyoNight = _build(
  Brightness.dark,
  const Color(0xFF7AA2F7), // blue
  surface: const Color(0xFF1A1B26), // bg
  lowest: const Color(0xFF121319),
  low: const Color(0xFF16161E), // bg-dark
  container: const Color(0xFF1F2335),
  high: const Color(0xFF292E42),
  highest: const Color(0xFF3B4261),
  onSurface: const Color(0xFFC0CAF5), // fg
  onSurfaceVariant: const Color(0xFF9AA5CE),
  outline: const Color(0xFF565F89), // comment
  onPrimary: const Color(0xFF16161E),
);

final _tokyoNightDay = _build(
  Brightness.light,
  const Color(0xFF2E7DE9), // blue
  surface: const Color(0xFFE1E2E7), // bg
  lowest: const Color(0xFFFFFFFF),
  low: const Color(0xFFD8D9E0),
  container: const Color(0xFFCDCED6),
  high: const Color(0xFFC0C2CC),
  highest: const Color(0xFFB3B6C3),
  onSurface: const Color(0xFF373A41),
  onSurfaceVariant: const Color(0xFF565A6E),
  outline: const Color(0xFF848CB5),
  onPrimary: const Color(0xFFFFFFFF),
);
