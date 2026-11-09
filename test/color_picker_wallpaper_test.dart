// The colour picker paints its own gradient slider tracks, and the wallpaper
// is a layer under the timeline that has to stay out of the way when unset.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/settings.dart';
import 'package:protea/src/widgets/chat_wallpaper.dart';
import 'package:protea/src/widgets/color_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child, AppSettings settings) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SettingsScope(
    settings: settings,
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('the picker returns the colour typed into the hex field', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late final AppSettings settings;
    await tester.runAsync(() async => settings = await AppSettings.load());
    Color? picked;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showColorPicker(
              context,
              initial: const Color(0xFF3F51B5),
              title: 'Accent',
            ),
            child: const Text('open'),
          ),
        ),
        settings,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Three gradient-tracked sliders rendered without blowing up.
    expect(find.byType(Slider), findsNWidgets(3));

    // Plain pumps from here on: a focused field blinks its cursor forever,
    // which pumpAndSettle would wait out.
    await tester.enterText(find.byType(TextField), '#FF8800');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(picked, const Color(0xFFFF8800));
  });

  testWidgets('the picker can be dismissed without choosing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late final AppSettings settings;
    await tester.runAsync(() async => settings = await AppSettings.load());
    var called = false;
    Color? picked;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showColorPicker(
                context,
                initial: const Color(0xFF3F51B5),
                title: 'Accent',
              );
              called = true;
            },
            child: const Text('open'),
          ),
        ),
        settings,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(picked, isNull);
  });

  testWidgets('the wallpaper layer is nothing at all when none is set', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late final AppSettings settings;
    late final File file;
    await tester.runAsync(() async {
      settings = await AppSettings.load();
      file = File('${Directory.systemTemp.path}/protea-wallpaper-test.png');
      await file.writeAsBytes(_onePixelPng);
    });
    addTearDown(() => file.existsSync() ? file.deleteSync() : null);
    await tester.pumpWidget(_app(const ChatWallpaper(), settings));
    expect(find.byType(Image), findsNothing);

    // A wallpaper shows through at the configured opacity, and never eats a
    // tap meant for the messages above it.
    await tester.runAsync(() async {
      await settings.setChatWallpaper(file.path);
      await settings.setChatWallpaperOpacity(0.4);
    });
    await tester.pumpWidget(_app(const ChatWallpaper(), settings));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(ChatWallpaper),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.4,
    );
    expect(
      find.descendant(
        of: find.byType(ChatWallpaper),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });
}

/// A 1x1 transparent PNG — enough for the widget tree, nothing to decode.
const _onePixelPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
