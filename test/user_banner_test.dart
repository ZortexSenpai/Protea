// The nameplate banner must fill its whole tile (cover) instead of sitting
// right-aligned at natural width, which left a bare dark stripe behind the
// username.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/widgets/mxc_avatar.dart';
import 'package:protea/src/widgets/user_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('nameplate banner covers the whole tile', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      FakeMatrixApi
              .currentApi!
              .api['GET']!['/client/v3/profile/%40banner%3Afake'] =
          (dynamic req) => {
            'displayname': 'Bannered',
            'chat.commet.profile_banner': 'mxc://fake/banner',
          };
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 48,
            width: 300,
            child: UserBannerBackground(
              client: client,
              userId: '@banner:fake',
              child: const Text('username'),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    final image = tester.widget<MxcImage>(find.byType(MxcImage));
    expect(image.fit, BoxFit.cover);
    expect(image.expand, isTrue);
    // The image spans the full tile, not a right-aligned natural-width box.
    expect(
      tester.getRect(find.byType(MxcImage)),
      tester.getRect(find.byType(UserBannerBackground)),
    );

    // Drain in-flight SDK work before the harness checks for stray timers.
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(seconds: 31));
    await tester.runAsync(() => client.dispose(closeDatabase: false));
  });
}
