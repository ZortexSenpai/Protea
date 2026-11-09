// A nameplate row recycled from one user to another must not keep the old
// user's banner: an in-flight profile fetch for the previous user may
// complete after the switch and must be discarded.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/src/widgets/mxc_avatar.dart';
import 'package:protea/src/widgets/user_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  testWidgets('recycled nameplate does not inherit the old user banner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late final Client client;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      FakeMatrixApi
              .currentApi!
              .api['GET']!['/client/v3/profile/%40user1%3Afake'] =
          (dynamic req) => {
            'displayname': 'One',
            'chat.commet.profile_banner': 'mxc://fake/banner1',
          };
      // user2 has no profile endpoint: the lookup fails -> no banner.
      // Pre-warm user2 so its (empty) result resolves faster than user1's.
      await fetchExtendedProfile(client, '@user2:fake');
    });

    Widget plate(String userId) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 48,
          width: 300,
          child: UserBannerBackground(
            client: client,
            userId: userId,
            child: const Text('row'),
          ),
        ),
      ),
    );

    // Mount for user1; its banner fetch is now in flight (no real-async
    // windows yet), then recycle the row to user2 before it completes.
    await tester.pumpWidget(plate('@user1:fake'));
    await tester.pumpWidget(plate('@user2:fake'));

    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // user2 has no banner; user1's late-arriving banner must not show.
    expect(find.byType(MxcImage), findsNothing);

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
