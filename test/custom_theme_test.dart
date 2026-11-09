// The custom theme is six colors; the rest of the Material role set is
// derived. The derivation has to keep the picked colors exactly and produce
// an elevation ramp that runs the right way for a light and a dark palette
// alike, or panels stop being distinguishable from the page behind them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/theme_code.dart';
import 'package:protea/src/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dark = CustomPalette(
  accent: Color(0xFFC2185B),
  background: Color(0xFF11111B),
  panel: Color(0xFF181825),
  text: Color(0xFFCDD6F4),
  mutedText: Color(0xFFA6ADC8),
  outline: Color(0xFF313244),
);

const _light = CustomPalette(
  accent: Color(0xFF1E66F5),
  background: Color(0xFFEFF1F5),
  panel: Color(0xFFDCE0E8),
  text: Color(0xFF4C4F69),
  mutedText: Color(0xFF6C6F85),
  outline: Color(0xFFBCC0CC),
);

double _lightness(Color color) => HSLColor.fromColor(color).lightness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a custom scheme keeps every color it was given', () {
    final scheme = customScheme(_dark, Brightness.dark);
    expect(scheme.primary, _dark.accent);
    expect(scheme.surface, _dark.background);
    expect(scheme.surfaceContainer, _dark.panel);
    expect(scheme.onSurface, _dark.text);
    expect(scheme.onSurfaceVariant, _dark.mutedText);
    expect(scheme.outline, _dark.outline);
    expect(scheme.brightness, Brightness.dark);
  });

  test('surfaces step away from the background, whichever way that is', () {
    final dark = customScheme(_dark, Brightness.dark);
    // Panel lighter than background: elevation lightens.
    expect([
      _lightness(dark.surfaceContainerLowest),
      _lightness(dark.surface),
      _lightness(dark.surfaceContainerLow),
      _lightness(dark.surfaceContainer),
      _lightness(dark.surfaceContainerHigh),
      _lightness(dark.surfaceContainerHighest),
    ], _isAscending);

    final light = customScheme(_light, Brightness.light);
    // Panel darker than background: the same ramp, the other way round.
    expect([
      _lightness(light.surfaceContainerHighest),
      _lightness(light.surfaceContainerHigh),
      _lightness(light.surfaceContainer),
      _lightness(light.surfaceContainerLow),
      _lightness(light.surface),
      _lightness(light.surfaceContainerLowest),
    ], _isAscending);
  });

  test('identical anchors still leave the tiers apart', () {
    // Picking the same color for background and panel would otherwise flatten
    // every surface into one, leaving cards invisible.
    final flat = _dark.copyWith(panel: _dark.background);
    final scheme = customScheme(flat, Brightness.dark);
    expect(scheme.surfaceContainerHigh, isNot(scheme.surface));
    expect(
      _lightness(scheme.surfaceContainerHigh),
      greaterThan(_lightness(scheme.surface)),
    );
  });

  test('text on the accent is whichever of black or white reads', () {
    expect(customScheme(_dark, Brightness.dark).onPrimary, Colors.white);
    expect(
      customScheme(
        _dark.copyWith(accent: const Color(0xFFFFE082)),
        Brightness.dark,
      ).onPrimary,
      Colors.black,
    );
  });

  test('an accent override recolors a theme that ships its own palette', () {
    final nord = schemeFor(
      AppTheme.nord,
      AppThemeColor.protea,
      Brightness.dark,
    );
    final accented = schemeFor(
      AppTheme.nord,
      AppThemeColor.protea,
      Brightness.dark,
      accent: const Color(0xFF00BFA5),
    );
    expect(accented.primary, const Color(0xFF00BFA5));
    // Only the accent roles move; the theme's own surfaces stay put.
    expect(accented.surface, nord.surface);
    expect(accented.onSurface, nord.onSurface);
    expect(accented.primaryContainer, isNot(nord.primaryContainer));
  });

  test('a palette code round-trips both palettes', () {
    final code = encodePaletteCode(_light, _dark);
    final decoded = decodePaletteCode(code);
    expect(decoded?.light, _light);
    expect(decoded?.dark, _dark);
    // Pasted out of a message, with whatever whitespace came along.
    expect(decodePaletteCode('  $code\n')?.dark, _dark);
  });

  test('a code that is not one is refused rather than half-applied', () {
    expect(decodePaletteCode(''), isNull);
    expect(decodePaletteCode('protea-theme-1.'), isNull);
    expect(decodePaletteCode('protea-theme-1.not base64!'), isNull);
    // Right prefix and valid base64, wrong number of colors.
    expect(decodePaletteCode('protea-theme-1.AAAA'), isNull);
    expect(decodePaletteCode('some other app code'), isNull);
  });

  test('a background color washes the page without touching anything else', () {
    final base = schemeFor(
      AppTheme.nord,
      AppThemeColor.protea,
      Brightness.dark,
    );
    const wash = Color(0xFF7E57C2);

    // Off by default: no color, or nothing to fade in, leaves the theme be.
    expect(withBackground(base, null, 0.5), base);
    expect(withBackground(base, wash, 0), base);

    final tinted = withBackground(base, wash, 0.5);
    expect(tinted.surface, Color.lerp(base.surface, wash, 0.5));
    // Panels, text and the accent keep the theme's own colors, so the wash
    // can't quietly wreck its contrast.
    expect(tinted.surfaceContainer, base.surfaceContainer);
    expect(tinted.surfaceContainerLowest, base.surfaceContainerLowest);
    expect(tinted.onSurface, base.onSurface);
    expect(tinted.primary, base.primary);

    // Full fade is the color itself, and a fade beyond it is clamped there.
    expect(withBackground(base, wash, 1).surface, wash);
    expect(withBackground(base, wash, 4).surface, wash);
  });

  test('the corner glow can be turned off for a flat backdrop', () {
    final scheme = schemeFor(
      AppTheme.nord,
      AppThemeColor.protea,
      Brightness.dark,
    );

    // On by default: a diagonal gradient whose corners carry the theme's
    // accent containers.
    final glowing = liquidBackdrop(scheme, null, 0);
    expect(glowing.color, isNull);
    final gradient = glowing.gradient as LinearGradient;
    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
    expect(gradient.colors.first, scheme.primaryContainer);
    expect(gradient.colors.last, scheme.tertiaryContainer);

    // Off: no gradient at all, one flat color.
    final flat = liquidBackdrop(scheme, null, 0, glow: false);
    expect(flat.gradient, isNull);
    expect(flat.color, scheme.surfaceContainerLowest);

    // A background color of one's own replaces the accent glow, and a flat
    // backdrop takes that color rather than falling back to the theme's.
    const wash = Color(0xFF7E57C2);
    final washedGlow = liquidBackdrop(scheme, wash, 0.5).gradient!;
    expect(washedGlow.colors.first, isNot(scheme.primaryContainer));
    expect(
      washedGlow.colors.first,
      Color.lerp(scheme.surfaceContainerLowest, wash, 0.5),
    );
    expect(
      liquidBackdrop(scheme, wash, 0.5, glow: false).color,
      Color.lerp(scheme.surfaceContainerLowest, wash, 0.5),
    );
  });

  test('the corner glow setting persists', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.backgroundGlow, isTrue);
    await settings.setBackgroundGlow(false);
    expect((await AppSettings.load()).backgroundGlow, isFalse);
  });

  test('the background color and its fade persist', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.appBackgroundColor, isNull);

    await settings.setAppBackgroundColor(const Color(0xFF7E57C2));
    await settings.setAppBackgroundFade(0.6);
    final reloaded = await AppSettings.load();
    expect(reloaded.appBackgroundColor, const Color(0xFF7E57C2));
    expect(reloaded.appBackgroundFade, 0.6);

    await reloaded.setAppBackgroundColor(null);
    expect(reloaded.appBackgroundColor, isNull);
    // Clearing the color keeps the fade, so turning it back on looks the
    // same as it did before.
    expect(reloaded.appBackgroundFade, 0.6);
  });

  test('the stored palette survives a reload and can be forgotten', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();

    // Before anything is stored the editor starts from the Material theme.
    expect(
      settings.customPalette(Brightness.dark).accent,
      schemeFor(
        AppTheme.material,
        settings.themeColor,
        Brightness.dark,
      ).primary,
    );
    expect(settings.hasCustomPalette(Brightness.dark), isFalse);

    await settings.setCustomPalette(Brightness.dark, _dark);
    expect(settings.hasCustomPalette(Brightness.dark), isTrue);
    expect(settings.customPalette(Brightness.dark), _dark);
    // The two brightnesses are stored apart.
    expect(settings.hasCustomPalette(Brightness.light), isFalse);

    final reloaded = await AppSettings.load();
    expect(reloaded.customPalette(Brightness.dark), _dark);

    await reloaded.resetCustomPalette(Brightness.dark);
    expect(reloaded.hasCustomPalette(Brightness.dark), isFalse);
  });

  test(
    'an accent override only applies where a theme brings no accent',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      await settings.setAccentOverride(AppThemeColor.mint);

      await settings.setAppTheme(AppTheme.nord);
      expect(settings.effectiveAccent, AppThemeColor.mint.seed);
      // Material seeds from its own color, and a custom theme carries one.
      await settings.setAppTheme(AppTheme.material);
      expect(settings.effectiveAccent, isNull);
      await settings.setAppTheme(AppTheme.custom);
      expect(settings.effectiveAccent, isNull);

      await settings.setAppTheme(AppTheme.nord);
      await settings.setAccentOverride(null);
      expect(settings.effectiveAccent, isNull);
    },
  );
}

/// Every value strictly greater than the one before it.
final Matcher _isAscending = predicate<List<double>>(
  (values) => [
    for (var i = 1; i < values.length; i++) values[i] > values[i - 1],
  ].every((ascends) => ascends),
  'ascends',
);
