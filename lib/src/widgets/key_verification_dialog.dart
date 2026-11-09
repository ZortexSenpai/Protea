import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n.dart';

/// Walks the user through an interactive device verification: accept the
/// request, then either let the other device scan the shown QR code or
/// compare emojis (SAS) and confirm.
class KeyVerificationDialog extends StatefulWidget {
  const KeyVerificationDialog({super.key, required this.request});

  final KeyVerification request;

  static Future<void> show(BuildContext context, KeyVerification request) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => KeyVerificationDialog(request: request),
      );

  @override
  State<KeyVerificationDialog> createState() => _KeyVerificationDialogState();
}

class _KeyVerificationDialogState extends State<KeyVerificationDialog> {
  KeyVerification get request => widget.request;

  final _ssssController = TextEditingController();
  bool _ssssBusy = false;
  String? _ssssError;

  @override
  void initState() {
    super.initState();
    request.onUpdate = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    request.onUpdate = null;
    _ssssController.dispose();
    super.dispose();
  }

  Future<void> _openSSSS() async {
    final key = _ssssController.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _ssssBusy = true;
      _ssssError = null;
    });
    try {
      await request.openSSSS(keyOrPassphrase: key);
    } catch (_) {
      if (mounted) {
        setState(() => _ssssError = context.l10n.couldNotUnlock);
      }
    } finally {
      if (mounted) setState(() => _ssssBusy = false);
    }
  }

  Future<void> _cancelAndClose() async {
    try {
      await request.cancel('m.user');
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Widget _body(BuildContext context) {
    switch (request.state) {
      case KeyVerificationState.askAccept:
        final deviceId = request.deviceId;
        return _Message(
          icon: Icons.verified_user_outlined,
          text: deviceId != null
              ? context.l10n.wantsToVerifyDeviceWithId(request.userId, deviceId)
              : context.l10n.wantsToVerifyDevice(request.userId),
        );
      case KeyVerificationState.waitingAccept:
        return _Message(
          spinner: true,
          text: context.l10n.waitingForOtherDeviceToAccept,
        );
      case KeyVerificationState.askChoice:
        final qrCode = request.qrCode;
        // Show a QR code when the other device can scan one; the emoji
        // comparison stays available as the action button below.
        if (qrCode == null ||
            !request.possibleMethods.contains(EventTypes.QRShow)) {
          return _Message(
            icon: Icons.emoji_emotions_outlined,
            text: context.l10n.compareEmojisToVerify,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.scanQrToVerify, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              // Fixed size: QrImageView's internal LayoutBuilder cannot
              // report intrinsics, which AlertDialog's IntrinsicWidth needs.
              width: 224,
              height: 224,
              padding: const EdgeInsets.all(12),
              // White backdrop keeps the code scannable in dark themes.
              color: Colors.white,
              child: QrImageView.withQr(
                qr: QrCode.fromUint8List(
                  data: Uint8List.fromList(qrCode.qrDataRawBytes),
                  errorCorrectLevel: QrErrorCorrectLevel.L,
                ),
                size: 200,
              ),
            ),
          ],
        );
      case KeyVerificationState.askSas:
        final emojis = request.sasTypes.contains('emoji')
            ? request.sasEmojis
            : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.compareAndConfirmMatch),
            const SizedBox(height: 16),
            if (emojis != null)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final emoji in emojis)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji.emoji, style: const TextStyle(fontSize: 32)),
                        Text(
                          emoji.name,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                ],
              )
            else
              Text(
                request.sasNumbers.join('  '),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
          ],
        );
      case KeyVerificationState.waitingSas:
        return _Message(
          spinner: true,
          text: context.l10n.waitingForOtherDeviceToConfirm,
        );
      case KeyVerificationState.done:
        return _Message(
          icon: Icons.verified_user,
          text: context.l10n.verificationSuccessful,
        );
      case KeyVerificationState.error:
        return _Message(
          icon: Icons.gpp_bad_outlined,
          text: context.l10n.verificationFailed(request.canceledReason ?? ''),
        );
      case KeyVerificationState.askSSSS:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.enterRecoveryKeyToVerify),
            const SizedBox(height: 16),
            TextField(
              controller: _ssssController,
              enabled: !_ssssBusy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.recoveryKey,
                border: const OutlineInputBorder(),
                errorText: _ssssError,
              ),
              onSubmitted: (_) => _openSSSS(),
            ),
          ],
        );
      case KeyVerificationState.showQRSuccess:
        // Scanner-side state; Protea only shows QR codes, but handle it
        // gracefully in case the SDK ever lands here.
        return _Message(
          spinner: true,
          text: context.l10n.waitingForOtherDeviceToConfirm,
        );
      case KeyVerificationState.confirmQRScan:
        // The other device scanned our code and its secret checked out;
        // the user confirms the other device reports success.
        return _Message(
          icon: Icons.qr_code_scanner,
          text: context.l10n.otherDeviceShowsShield,
        );
    }
  }

  List<Widget> _actions(BuildContext context) {
    switch (request.state) {
      case KeyVerificationState.askAccept:
        return [
          TextButton(
            onPressed: () async {
              await request.rejectVerification();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(context.l10n.decline),
          ),
          FilledButton(
            onPressed: () => request.acceptVerification(),
            child: Text(context.l10n.accept),
          ),
        ];
      case KeyVerificationState.askChoice:
        return [
          TextButton(
            onPressed: _cancelAndClose,
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => request.continueVerification(EventTypes.Sas),
            child: Text(context.l10n.compareEmojis),
          ),
        ];
      case KeyVerificationState.askSas:
        return [
          TextButton(
            onPressed: () async {
              await request.rejectSas();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(context.l10n.theyDontMatch),
          ),
          FilledButton(
            onPressed: () => request.acceptSas(),
            child: Text(context.l10n.theyMatch),
          ),
        ];
      case KeyVerificationState.waitingAccept:
      case KeyVerificationState.waitingSas:
        return [
          TextButton(
            onPressed: _cancelAndClose,
            child: Text(context.l10n.cancel),
          ),
        ];
      case KeyVerificationState.done:
      case KeyVerificationState.error:
        return [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.close),
          ),
        ];
      case KeyVerificationState.askSSSS:
        return [
          TextButton(
            onPressed: _ssssBusy ? null : () => request.openSSSS(skip: true),
            child: Text(context.l10n.skip),
          ),
          FilledButton(
            onPressed: _ssssBusy ? null : _openSSSS,
            child: _ssssBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.unlock),
          ),
        ];
      case KeyVerificationState.showQRSuccess:
        return [
          TextButton(
            onPressed: _cancelAndClose,
            child: Text(context.l10n.cancel),
          ),
        ];
      case KeyVerificationState.confirmQRScan:
        return [
          TextButton(
            onPressed: _cancelAndClose,
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => request.acceptQRScanConfirmation(),
            child: Text(context.l10n.yesVerify),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.verifyDevice),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _body(context),
      ),
      actions: _actions(context),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.icon, this.spinner = false});

  final String text;
  final IconData? icon;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spinner)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: CircularProgressIndicator(),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        Text(text),
      ],
    );
  }
}

/// Listens for incoming verification requests (e.g. started from another
/// client like Element) and pops up the verification dialog.
class KeyVerificationListener extends StatefulWidget {
  const KeyVerificationListener({
    super.key,
    required this.client,
    required this.child,
  });

  final Client client;
  final Widget child;

  @override
  State<KeyVerificationListener> createState() =>
      _KeyVerificationListenerState();
}

class _KeyVerificationListenerState extends State<KeyVerificationListener> {
  StreamSubscription<KeyVerification>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.client.onKeyVerificationRequest.stream.listen((
      request,
    ) {
      if (mounted) KeyVerificationDialog.show(context, request);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
