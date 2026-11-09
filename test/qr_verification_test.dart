// QR show-side verification: when the other device can scan
// (m.qr_code.show.v1 is a possible method), the choice step renders the
// SDK's QR payload with the emoji comparison still available, and the
// confirm step verifies via acceptQRScanConfirmation.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:protea/l10n/generated/app_localizations.dart';
import 'package:protea/src/widgets/key_verification_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:typed_data/typed_data.dart';

import 'fake_client.dart';

void main() {
  testWidgets('choice step shows a scannable QR when the peer can scan', (
    tester,
  ) async {
    late final Client client;
    late final KeyVerification request;
    await tester.runAsync(() async {
      client = await buildFakeClient();
      // The fake client runs without vodozemac, so encryption is not
      // enabled on it; the dialog only reads fields off the request, so a
      // bare Encryption wrapper is enough.
      request = KeyVerification(
        encryption: client.encryption ?? Encryption(client: client),
        userId: fakeUserId,
        deviceId: 'OTHERDEVICE',
      );
      request.possibleMethods = [EventTypes.QRShow, EventTypes.Sas];
      request.qrCode = QRCode(
        'randomsharedsecret',
        Uint8Buffer()..addAll(utf8.encode('MATRIX qr payload stand-in')),
      );
      request.setState(KeyVerificationState.askChoice);
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: KeyVerificationDialog(request: request)),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(KeyVerificationDialog)),
    );

    // The QR code renders, with emoji comparison offered alongside.
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(l10n.scanQrToVerify), findsOneWidget);
    expect(find.text(l10n.compareEmojis), findsOneWidget);

    // After the peer scans, the confirm step offers the verify button.
    await tester.runAsync(
      () async => request.setState(KeyVerificationState.confirmQRScan),
    );
    await tester.pump();
    expect(find.text(l10n.otherDeviceShowsShield), findsOneWidget);
    expect(find.text(l10n.yesVerify), findsOneWidget);

    // Without a scan-capable peer the step falls back to emoji-only.
    await tester.runAsync(() async {
      request.possibleMethods = [EventTypes.Sas];
      request.setState(KeyVerificationState.askChoice);
    });
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text(l10n.compareEmojisToVerify), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => client.dispose(closeDatabase: false));
  });
}
