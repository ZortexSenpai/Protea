import 'package:flutter/material.dart';

enum AppTheme {
  material('Material'),
  custom('Custom'),
  oled('OLED'),
  // 'catppuccin' predates the other flavors and stays Mocha so stored
  // selections keep working. Flavors are ordered darkest to lightest.
  catppuccinOled('Catppuccin OLED'),
  catppuccin('Catppuccin Mocha'),
  catppuccinMacchiato('Catppuccin Macchiato'),
  catppuccinFrappe('Catppuccin Frappé'),
  nord('Nord'),
  dracula('Dracula'),
  gruvbox('Gruvbox'),
  tokyoNight('Tokyo Night'),
  rosePine('Rosé Pine'),
  everforest('Everforest'),
  solarized('Solarized'),
  oneDark('One Dark'),
  monokai('Monokai'),
  kanagawa('Kanagawa'),
  ayu('Ayu'),
  github('GitHub'),
  nightOwl('Night Owl'),
  palenight('Palenight'),
  zenburn('Zenburn');

  const AppTheme(this.label);

  final String label;
}

/// Seed colors for the Material theme. Each seed generates a full light and
/// dark Material color scheme via [ColorScheme.fromSeed].
enum AppThemeColor {
  // Roughly ordered around the color wheel, warm to cool.
  protea(Color(0xFFC2185B), 'Protea'),
  crimson(Color(0xFFC62828), 'Crimson'),
  sunset(Color(0xFFE64A19), 'Sunset'),
  amber(Color(0xFFFFA000), 'Amber'),
  gold(Color(0xFFF9A825), 'Gold'),
  forest(Color(0xFF689F38), 'Forest'),
  mint(Color(0xFF00BFA5), 'Mint'),
  teal(Color(0xFF00796B), 'Teal'),
  ocean(Color(0xFF0288D1), 'Ocean'),
  indigo(Color(0xFF3F51B5), 'Indigo'),
  midnight(Color(0xFF1A237E), 'Midnight'),
  lavender(Color(0xFF7E57C2), 'Lavender'),
  violet(Color(0xFF7B1FA2), 'Violet'),
  mocha(Color(0xFF795548), 'Mocha'),
  graphite(Color(0xFF546E7A), 'Graphite');

  const AppThemeColor(this.seed, this.label);

  final Color seed;
  final String label;
}

/// The six colors a custom theme is built from. The rest of the Material role
/// set is derived: the surface elevation tiers are shaded around [background]
/// and [panel], and the color on the accent is whichever of black or white
/// reads on it.
@immutable
class CustomPalette {
  const CustomPalette({
    required this.accent,
    required this.background,
    required this.panel,
    required this.text,
    required this.mutedText,
    required this.outline,
  });

  /// The palette of an existing [scheme], so a custom theme can start from
  /// the theme already in use instead of from nothing.
  factory CustomPalette.fromScheme(ColorScheme scheme) => CustomPalette(
    accent: scheme.primary,
    background: scheme.surface,
    panel: scheme.surfaceContainer,
    text: scheme.onSurface,
    mutedText: scheme.onSurfaceVariant,
    outline: scheme.outline,
  );

  /// The accent, and the base every other accent role is generated from.
  final Color accent;

  /// The page behind everything ([ColorScheme.surface]).
  final Color background;

  /// Cards, panels and raised rows ([ColorScheme.surfaceContainer]), and with
  /// [background] the size of one elevation step.
  final Color panel;

  final Color text;
  final Color mutedText;
  final Color outline;

  CustomPalette copyWith({
    Color? accent,
    Color? background,
    Color? panel,
    Color? text,
    Color? mutedText,
    Color? outline,
  }) => CustomPalette(
    accent: accent ?? this.accent,
    background: background ?? this.background,
    panel: panel ?? this.panel,
    text: text ?? this.text,
    mutedText: mutedText ?? this.mutedText,
    outline: outline ?? this.outline,
  );

  /// The colors in a fixed order, for storing and for the palette code.
  List<Color> get colors => [
    accent,
    background,
    panel,
    text,
    mutedText,
    outline,
  ];

  /// Rebuilds a palette from [colors] in the order [CustomPalette.colors]
  /// produces, or null when there aren't exactly six.
  static CustomPalette? fromColors(List<Color> colors) => colors.length == 6
      ? CustomPalette(
          accent: colors[0],
          background: colors[1],
          panel: colors[2],
          text: colors[3],
          mutedText: colors[4],
          outline: colors[5],
        )
      : null;

  @override
  bool operator ==(Object other) =>
      other is CustomPalette &&
      other.accent == accent &&
      other.background == background &&
      other.panel == panel &&
      other.text == text &&
      other.mutedText == mutedText &&
      other.outline == outline;

  @override
  int get hashCode =>
      Object.hash(accent, background, panel, text, mutedText, outline);
}

/// Black or white, whichever reads on [color].
Color onColorFor(Color color) =>
    color.computeLuminance() > 0.45 ? Colors.black : Colors.white;

/// Builds the full role set of a custom theme from its six colors.
///
/// [CustomPalette.background] and [CustomPalette.panel] give both the base and
/// the size of one elevation step, so the ramp runs the right way for a light
/// and a dark palette alike without asking which is which. Two identical
/// anchors would flatten every surface into one color, so the step falls back
/// to a small one in the direction [brightness] implies.
ColorScheme customScheme(CustomPalette palette, Brightness brightness) {
  final background = HSLColor.fromColor(palette.background);
  final panel = HSLColor.fromColor(palette.panel);
  var step = panel.lightness - background.lightness;
  if (step.abs() < 0.01) step = brightness == Brightness.dark ? 0.04 : -0.04;
  Color shade(HSLColor from, double steps) => from
      .withLightness((from.lightness + step * steps).clamp(0.0, 1.0))
      .toColor();
  return _build(
    brightness,
    palette.accent,
    surface: palette.background,
    lowest: shade(background, -1),
    low: shade(background, 0.5),
    container: palette.panel,
    high: shade(panel, 0.6),
    highest: shade(panel, 1.2),
    onSurface: palette.text,
    onSurfaceVariant: palette.mutedText,
    outline: palette.outline,
    onPrimary: onColorFor(palette.accent),
  );
}

/// Recolors [scheme]'s accent roles, for wearing a chosen accent on a theme
/// that ships its own palette. The containers are the accent carried most of
/// the way to the surface, so they stay in the theme's own register.
ColorScheme withAccent(ColorScheme scheme, Color accent) {
  final dark = scheme.brightness == Brightness.dark;
  final container = Color.lerp(accent, scheme.surface, dark ? 0.68 : 0.8)!;
  return scheme.copyWith(
    primary: accent,
    onPrimary: onColorFor(accent),
    primaryContainer: container,
    onPrimaryContainer: onColorFor(container),
  );
}

/// Washes [scheme]'s backdrop with [color], [fade] of the way from the
/// theme's own surface to it.
///
/// Only [ColorScheme.surface] moves — the page behind everything. Panels,
/// cards and the text roles keep the theme's colors, so a background of
/// one's own can't quietly wreck the contrast the theme was built with.
ColorScheme withBackground(ColorScheme scheme, Color? color, double fade) {
  final amount = fade.clamp(0.0, 1.0);
  if (color == null || amount <= 0) return scheme;
  return scheme.copyWith(surface: Color.lerp(scheme.surface, color, amount));
}

/// The backdrop behind the Liquid layout's glass panels.
///
/// With [glow] the corners carry color — the theme's own accent containers,
/// or [background] at [fade] when one is set — and with it off the whole
/// backdrop is that one flat color instead.
BoxDecoration liquidBackdrop(
  ColorScheme scheme,
  Color? background,
  double fade, {
  bool glow = true,
}) {
  Color washed(double strength) => background == null || fade <= 0
      ? scheme.surfaceContainerLowest
      : Color.lerp(
          scheme.surfaceContainerLowest,
          background,
          (fade * strength).clamp(0.0, 1.0),
        )!;
  if (!glow) return BoxDecoration(color: washed(1));
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: background == null
          ? [
              scheme.primaryContainer,
              scheme.surfaceContainerLowest,
              scheme.tertiaryContainer,
            ]
          : [washed(1), washed(0.15), washed(0.7)],
    ),
  );
}

/// Full color schemes for the selectable app themes. Each non-Material
/// theme is built from its palette's accent seed and then overridden with
/// the palette's canonical background/surface/text colors, so the whole
/// Material role set stays populated and harmonious.
///
/// [custom] supplies the colors for [AppTheme.custom]; [accent] recolors the
/// result whatever the theme, and callers pass it only for themes where an
/// accent of one's own makes sense (not Material, which seeds from one
/// already, nor a custom theme, which carries its own).
ColorScheme schemeFor(
  AppTheme theme,
  AppThemeColor seed,
  Brightness brightness, {
  CustomPalette? custom,
  Color? accent,
}) {
  final scheme = _schemeFor(theme, seed, brightness, custom);
  return accent == null ? scheme : withAccent(scheme, accent);
}

ColorScheme _schemeFor(
  AppTheme theme,
  AppThemeColor seed,
  Brightness brightness,
  CustomPalette? custom,
) {
  final dark = brightness == Brightness.dark;
  return switch (theme) {
    AppTheme.custom => customScheme(
      custom ?? CustomPalette.fromScheme(_materialScheme(seed, brightness)),
      brightness,
    ),
    AppTheme.material => _materialScheme(seed, brightness),
    AppTheme.oled => dark ? _oledDark : _oledLight,
    // All Catppuccin flavors share Latte as their light counterpart, per
    // the official palette.
    AppTheme.catppuccinOled => dark ? _catppuccinOled : _catppuccinLatte,
    AppTheme.catppuccin => dark ? _catppuccinMocha : _catppuccinLatte,
    AppTheme.catppuccinMacchiato =>
      dark ? _catppuccinMacchiato : _catppuccinLatte,
    AppTheme.catppuccinFrappe => dark ? _catppuccinFrappe : _catppuccinLatte,
    AppTheme.nord => dark ? _nordDark : _nordLight,
    AppTheme.dracula => dark ? _dracula : _draculaLight,
    AppTheme.gruvbox => dark ? _gruvboxDark : _gruvboxLight,
    AppTheme.tokyoNight => dark ? _tokyoNight : _tokyoNightDay,
    AppTheme.rosePine => dark ? _rosePine : _rosePineDawn,
    AppTheme.everforest => dark ? _everforestDark : _everforestLight,
    AppTheme.solarized => dark ? _solarizedDark : _solarizedLight,
    AppTheme.oneDark => dark ? _oneDark : _oneLight,
    AppTheme.monokai => dark ? _monokai : _monokaiLight,
    AppTheme.kanagawa => dark ? _kanagawaWave : _kanagawaLotus,
    AppTheme.ayu => dark ? _ayuDark : _ayuLight,
    AppTheme.github => dark ? _githubDark : _githubLight,
    AppTheme.nightOwl => dark ? _nightOwl : _lightOwl,
    AppTheme.palenight => dark ? _palenight : _palenightLight,
    AppTheme.zenburn => dark ? _zenburn : _zenburnLight,
  };
}

ColorScheme _materialScheme(AppThemeColor seed, Brightness brightness) =>
    ColorScheme.fromSeed(seedColor: seed.seed, brightness: brightness);

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

// ---- OLED ------------------------------------------------------------------
// True black for OLED panels: the base surfaces are pure black so those
// pixels switch off entirely; panels separate through near-black elevation
// steps and hairlines instead of tinted grays. Its light counterpart is a
// plain high-contrast white.

final _oledDark = _build(
  Brightness.dark,
  const Color(0xFF448AFF), // electric blue, vivid on black
  surface: const Color(0xFF000000),
  lowest: const Color(0xFF000000),
  low: const Color(0xFF050505),
  container: const Color(0xFF121212),
  high: const Color(0xFF1B1B1B),
  highest: const Color(0xFF262626),
  onSurface: const Color(0xFFE6E6E6),
  onSurfaceVariant: const Color(0xFFB0B0B0),
  outline: const Color(0xFF707070),
  onPrimary: const Color(0xFF000000),
);

final _oledLight = _build(
  Brightness.light,
  const Color(0xFF2962FF),
  surface: const Color(0xFFFFFFFF),
  lowest: const Color(0xFFFFFFFF),
  low: const Color(0xFFF7F7F7),
  container: const Color(0xFFEFEFEF),
  high: const Color(0xFFE4E4E4),
  highest: const Color(0xFFD8D8D8),
  onSurface: const Color(0xFF111111),
  onSurfaceVariant: const Color(0xFF555555),
  outline: const Color(0xFF8A8A8A),
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- Catppuccin (Mocha / Latte) -------------------------------------------

/// The community AMOLED variant: Mocha's accents and text on a pure black
/// base, with Mocha's own darks reused as the elevation steps.
final _catppuccinOled = _build(
  Brightness.dark,
  const Color(0xFFCBA6F7), // mauve
  surface: const Color(0xFF000000),
  lowest: const Color(0xFF000000),
  low: const Color(0xFF0B0B12),
  container: const Color(0xFF11111B), // crust
  high: const Color(0xFF181825), // mantle
  highest: const Color(0xFF313244), // surface0
  onSurface: const Color(0xFFCDD6F4), // text
  onSurfaceVariant: const Color(0xFFA6ADC8), // subtext0
  outline: const Color(0xFF7F849C), // overlay1
  onPrimary: const Color(0xFF11111B),
);

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

final _catppuccinMacchiato = _build(
  Brightness.dark,
  const Color(0xFFC6A0F6), // mauve
  surface: const Color(0xFF24273A), // base
  lowest: const Color(0xFF181926), // crust
  low: const Color(0xFF1E2030), // mantle
  container: const Color(0xFF363A4F), // surface0
  high: const Color(0xFF494D64), // surface1
  highest: const Color(0xFF5B6078), // surface2
  onSurface: const Color(0xFFCAD3F5), // text
  onSurfaceVariant: const Color(0xFFA5ADCB), // subtext0
  outline: const Color(0xFF8087A2), // overlay1
  onPrimary: const Color(0xFF181926),
);

final _catppuccinFrappe = _build(
  Brightness.dark,
  const Color(0xFFCA9EE6), // mauve
  surface: const Color(0xFF303446), // base
  lowest: const Color(0xFF232634), // crust
  low: const Color(0xFF292C3C), // mantle
  container: const Color(0xFF414559), // surface0
  high: const Color(0xFF51576D), // surface1
  highest: const Color(0xFF626880), // surface2
  onSurface: const Color(0xFFC6D0F5), // text
  onSurfaceVariant: const Color(0xFFA5ADCE), // subtext0
  outline: const Color(0xFF838BA7), // overlay1
  onPrimary: const Color(0xFF232634),
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

// ---- Rosé Pine (main / Dawn) -----------------------------------------------

final _rosePine = _build(
  Brightness.dark,
  const Color(0xFFEBBCBA), // rose
  surface: const Color(0xFF191724), // base
  lowest: const Color(0xFF12101A),
  low: const Color(0xFF16141F),
  container: const Color(0xFF1F1D2E), // surface
  high: const Color(0xFF26233A), // overlay
  highest: const Color(0xFF403D52), // highlight med
  onSurface: const Color(0xFFE0DEF4), // text
  onSurfaceVariant: const Color(0xFF908CAA), // subtle
  outline: const Color(0xFF6E6A86), // muted
  onPrimary: const Color(0xFF191724),
);

final _rosePineDawn = _build(
  Brightness.light,
  const Color(0xFFD7827E), // rose
  surface: const Color(0xFFFAF4ED), // base
  lowest: const Color(0xFFFFFAF3), // surface
  low: const Color(0xFFF4EDE8), // highlight low
  container: const Color(0xFFF2E9E1), // overlay
  high: const Color(0xFFDFDAD9), // highlight med
  highest: const Color(0xFFCECACD), // highlight high
  onSurface: const Color(0xFF575279), // text
  onSurfaceVariant: const Color(0xFF797593), // subtle
  outline: const Color(0xFF9893A5), // muted
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- Everforest (medium) ---------------------------------------------------

final _everforestDark = _build(
  Brightness.dark,
  const Color(0xFFA7C080), // green
  surface: const Color(0xFF2D353B), // bg0
  lowest: const Color(0xFF232A2E), // bg_dim
  low: const Color(0xFF283136),
  container: const Color(0xFF343F44), // bg1
  high: const Color(0xFF3D484D), // bg2
  highest: const Color(0xFF475258), // bg3
  onSurface: const Color(0xFFD3C6AA), // fg
  onSurfaceVariant: const Color(0xFF9DA9A0), // grey2
  outline: const Color(0xFF859289), // grey1
  onPrimary: const Color(0xFF2D353B),
);

final _everforestLight = _build(
  Brightness.light,
  const Color(0xFF8DA101), // green
  surface: const Color(0xFFFDF6E3), // bg0
  lowest: const Color(0xFFFFFCF0),
  low: const Color(0xFFF4F0D9), // bg1
  container: const Color(0xFFEFEBD4), // bg2
  high: const Color(0xFFE6E2CC), // bg3
  highest: const Color(0xFFE0DCC7), // bg4
  onSurface: const Color(0xFF5C6A72), // fg
  onSurfaceVariant: const Color(0xFF7A8478), // grey0
  outline: const Color(0xFF939F91), // grey1
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- Solarized -------------------------------------------------------------

final _solarizedDark = _build(
  Brightness.dark,
  const Color(0xFF268BD2), // blue
  surface: const Color(0xFF002B36), // base03
  lowest: const Color(0xFF00212B),
  low: const Color(0xFF00252F),
  container: const Color(0xFF073642), // base02
  high: const Color(0xFF10454F),
  highest: const Color(0xFF1A5361),
  onSurface: const Color(0xFF93A1A1), // base1
  onSurfaceVariant: const Color(0xFF839496), // base0
  outline: const Color(0xFF586E75), // base01
  onPrimary: const Color(0xFFFDF6E3),
);

final _solarizedLight = _build(
  Brightness.light,
  const Color(0xFF268BD2), // blue
  surface: const Color(0xFFFDF6E3), // base3
  lowest: const Color(0xFFFFFCF2),
  low: const Color(0xFFF5EEDC),
  container: const Color(0xFFEEE8D5), // base2
  high: const Color(0xFFE4DDC8),
  highest: const Color(0xFFD9D2BC),
  onSurface: const Color(0xFF586E75), // base01
  onSurfaceVariant: const Color(0xFF657B83), // base00
  outline: const Color(0xFF93A1A1), // base1
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- One Dark / One Light --------------------------------------------------

final _oneDark = _build(
  Brightness.dark,
  const Color(0xFF61AFEF), // blue
  surface: const Color(0xFF282C34), // bg
  lowest: const Color(0xFF1E222A),
  low: const Color(0xFF21252B),
  container: const Color(0xFF2C313A),
  high: const Color(0xFF333842),
  highest: const Color(0xFF3E4451), // selection
  onSurface: const Color(0xFFABB2BF), // fg
  onSurfaceVariant: const Color(0xFF9DA5B4),
  outline: const Color(0xFF5C6370), // comment
  onPrimary: const Color(0xFF282C34),
);

final _oneLight = _build(
  Brightness.light,
  const Color(0xFF4078F2), // blue
  surface: const Color(0xFFFAFAFA), // bg
  lowest: const Color(0xFFFFFFFF),
  low: const Color(0xFFF0F0F1),
  container: const Color(0xFFE5E5E6),
  high: const Color(0xFFDBDBDC),
  highest: const Color(0xFFCACACB),
  onSurface: const Color(0xFF383A42), // fg
  onSurfaceVariant: const Color(0xFF696C77),
  outline: const Color(0xFFA0A1A7),
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- Monokai ---------------------------------------------------------------

final _monokai = _build(
  Brightness.dark,
  const Color(0xFFA6E22E), // green
  surface: const Color(0xFF272822), // bg
  lowest: const Color(0xFF1D1E19),
  low: const Color(0xFF22231E),
  container: const Color(0xFF34352F),
  high: const Color(0xFF3E3D32),
  highest: const Color(0xFF49483E), // selection
  onSurface: const Color(0xFFF8F8F2), // fg
  onSurfaceVariant: const Color(0xFFB1B1A0),
  outline: const Color(0xFF75715E), // comment
  onPrimary: const Color(0xFF272822),
);

/// Monokai has no official light palette; a seed-derived scheme keeps the
/// green identity in light mode.
final _monokaiLight = ColorScheme.fromSeed(seedColor: const Color(0xFF6E9A1F));

// ---- Kanagawa (Wave / Lotus) ------------------------------------------------

final _kanagawaWave = _build(
  Brightness.dark,
  const Color(0xFF7E9CD8), // crystal blue
  surface: const Color(0xFF1F1F28), // sumiInk1
  lowest: const Color(0xFF16161D), // sumiInk0
  low: const Color(0xFF1A1A22),
  container: const Color(0xFF2A2A37), // sumiInk2
  high: const Color(0xFF363646), // sumiInk3
  highest: const Color(0xFF54546D), // sumiInk4
  onSurface: const Color(0xFFDCD7BA), // fuji white
  onSurfaceVariant: const Color(0xFFC8C093), // old white
  outline: const Color(0xFF727169), // fuji gray
  onPrimary: const Color(0xFF16161D),
);

final _kanagawaLotus = _build(
  Brightness.light,
  const Color(0xFF4D699B), // lotus blue
  surface: const Color(0xFFF2ECBC), // lotusWhite3
  lowest: const Color(0xFFFBF7E3),
  low: const Color(0xFFECE6B6),
  container: const Color(0xFFE5DDB0), // lotusWhite2
  high: const Color(0xFFDCD5AC), // lotusWhite1
  highest: const Color(0xFFD5CEA3), // lotusWhite0
  onSurface: const Color(0xFF545464), // lotus ink
  onSurfaceVariant: const Color(0xFF716E61), // lotus gray
  outline: const Color(0xFF8A8980),
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- Ayu -------------------------------------------------------------------

final _ayuDark = _build(
  Brightness.dark,
  const Color(0xFFE6B450), // gold
  surface: const Color(0xFF0B0E14), // bg
  lowest: const Color(0xFF050708),
  low: const Color(0xFF080B10),
  container: const Color(0xFF0F131A), // panel
  high: const Color(0xFF151A22),
  highest: const Color(0xFF1C222C),
  onSurface: const Color(0xFFBFBDB6), // fg
  onSurfaceVariant: const Color(0xFF8A9199),
  outline: const Color(0xFF565B66),
  onPrimary: const Color(0xFF0B0E14),
);

final _ayuLight = _build(
  Brightness.light,
  const Color(0xFFFA8D3E), // orange
  surface: const Color(0xFFFAFAFA), // bg
  lowest: const Color(0xFFFFFFFF),
  low: const Color(0xFFF3F4F5), // panel
  container: const Color(0xFFE7E9EB),
  high: const Color(0xFFDDE0E3),
  highest: const Color(0xFFD2D6DA),
  onSurface: const Color(0xFF5C6166), // fg
  onSurfaceVariant: const Color(0xFF787B80),
  outline: const Color(0xFF9DA1A6),
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- GitHub ----------------------------------------------------------------

final _githubDark = _build(
  Brightness.dark,
  const Color(0xFF58A6FF), // blue
  surface: const Color(0xFF0D1117), // canvas
  lowest: const Color(0xFF010409), // canvas inset
  low: const Color(0xFF090D12),
  container: const Color(0xFF161B22), // canvas subtle
  high: const Color(0xFF21262D),
  highest: const Color(0xFF30363D), // border
  onSurface: const Color(0xFFE6EDF3), // fg
  onSurfaceVariant: const Color(0xFF8B949E), // fg muted
  outline: const Color(0xFF6E7681), // fg subtle
  onPrimary: const Color(0xFF0D1117),
);

final _githubLight = _build(
  Brightness.light,
  const Color(0xFF0969DA), // blue
  surface: const Color(0xFFFFFFFF), // canvas
  lowest: const Color(0xFFFBFCFD),
  low: const Color(0xFFF6F8FA), // canvas subtle
  container: const Color(0xFFEAEEF2),
  high: const Color(0xFFDEE3E9),
  highest: const Color(0xFFD0D7DE), // border
  onSurface: const Color(0xFF1F2328), // fg
  onSurfaceVariant: const Color(0xFF59636E), // fg muted
  outline: const Color(0xFF8C959F),
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- Night Owl / Light Owl --------------------------------------------------

final _nightOwl = _build(
  Brightness.dark,
  const Color(0xFF82AAFF), // blue
  surface: const Color(0xFF011627), // bg
  lowest: const Color(0xFF010E1A),
  low: const Color(0xFF01111F),
  container: const Color(0xFF0B2942), // panel
  high: const Color(0xFF1D3B53), // selection
  highest: const Color(0xFF2C4A63),
  onSurface: const Color(0xFFD6DEEB), // fg
  onSurfaceVariant: const Color(0xFFA9B8CC),
  outline: const Color(0xFF5F7E97),
  onPrimary: const Color(0xFF011627),
);

final _lightOwl = _build(
  Brightness.light,
  const Color(0xFF4876D6), // blue
  surface: const Color(0xFFFBFBFB), // bg
  lowest: const Color(0xFFFFFFFF),
  low: const Color(0xFFF0F0F0),
  container: const Color(0xFFE8ECEE),
  high: const Color(0xFFE0E7EA), // selection
  highest: const Color(0xFFD0D9DD),
  onSurface: const Color(0xFF403F53), // fg
  onSurfaceVariant: const Color(0xFF625F72),
  outline: const Color(0xFF90A7B2),
  onPrimary: const Color(0xFFFFFFFF),
);

// ---- Palenight -------------------------------------------------------------

final _palenight = _build(
  Brightness.dark,
  const Color(0xFFC792EA), // purple
  surface: const Color(0xFF292D3E), // bg
  lowest: const Color(0xFF1B1E2B),
  low: const Color(0xFF222634),
  container: const Color(0xFF32374D),
  high: const Color(0xFF3A4162),
  highest: const Color(0xFF444267), // selection
  onSurface: const Color(0xFFBFC7D5), // bright fg
  onSurfaceVariant: const Color(0xFFA6ACCD), // fg
  outline: const Color(0xFF676E95), // comment
  onPrimary: const Color(0xFF1B1E2B),
);

/// Palenight has no official light palette; a seed-derived scheme keeps the
/// purple identity in light mode.
final _palenightLight = ColorScheme.fromSeed(
  seedColor: const Color(0xFFC792EA),
);

// ---- Zenburn ---------------------------------------------------------------

final _zenburn = _build(
  Brightness.dark,
  const Color(0xFFF0DFAF), // yellow
  surface: const Color(0xFF3F3F3F), // bg
  lowest: const Color(0xFF2B2B2B),
  low: const Color(0xFF353535),
  container: const Color(0xFF4F4F4F),
  high: const Color(0xFF5F5F5F),
  highest: const Color(0xFF6C6C6C),
  onSurface: const Color(0xFFDCDCCC), // fg
  onSurfaceVariant: const Color(0xFFC0C0B0),
  outline: const Color(0xFF8F8F7F),
  onPrimary: const Color(0xFF2B2B2B),
);

/// Zenburn has no official light palette; a seed-derived scheme keeps the
/// muted green identity in light mode.
final _zenburnLight = ColorScheme.fromSeed(seedColor: const Color(0xFF7F9F7F));
