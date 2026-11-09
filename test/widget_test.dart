import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:protea/src/widgets/initials_avatar.dart';

void main() {
  testWidgets('InitialsAvatar shows the first letter of the name',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: InitialsAvatar(name: '@alice:matrix.org')),
      ),
    );
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('InitialsAvatar falls back to ? for empty names',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InitialsAvatar(name: ''))),
    );
    expect(find.text('?'), findsOneWidget);
  });
}
