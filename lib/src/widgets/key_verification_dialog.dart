import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

/// Walks the user through an interactive device verification (SAS):
/// accept the request, compare the emojis and confirm.
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
        setState(
          () => _ssssError = 'Could not unlock. Please check the recovery key.',
        );
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
        return _Message(
          icon: Icons.verified_user_outlined,
          text:
              '${request.userId} wants to verify a device'
              '${request.deviceId != null ? ' (${request.deviceId})' : ''}.',
        );
      case KeyVerificationState.waitingAccept:
        return const _Message(
          spinner: true,
          text:
              'Waiting for the other device to accept…\n\n'
              'Make sure the other device is online and the request was '
              'accepted there.',
        );
      case KeyVerificationState.askChoice:
        return const _Message(
          icon: Icons.emoji_emotions_outlined,
          text:
              'Compare a short list of emojis with the other device to '
              'verify it.',
        );
      case KeyVerificationState.askSas:
        final emojis = request.sasTypes.contains('emoji')
            ? request.sasEmojis
            : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Compare with the other device. Confirm only if they match '
              'exactly, in the same order.',
            ),
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
        return const _Message(
          spinner: true,
          text: 'Waiting for the other device to confirm…',
        );
      case KeyVerificationState.done:
        return const _Message(
          icon: Icons.verified_user,
          text: 'Verification successful! The device is now trusted.',
        );
      case KeyVerificationState.error:
        return _Message(
          icon: Icons.gpp_bad_outlined,
          text:
              'Verification failed or was cancelled.\n'
              '${request.canceledReason ?? ''}',
        );
      case KeyVerificationState.askSSSS:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your recovery key to verify with your secure backup, '
              'or skip to compare emojis with the other device instead.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ssssController,
              enabled: !_ssssBusy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Recovery key',
                border: const OutlineInputBorder(),
                errorText: _ssssError,
              ),
              onSubmitted: (_) => _openSSSS(),
            ),
          ],
        );
      case KeyVerificationState.showQRSuccess:
      case KeyVerificationState.confirmQRScan:
        return const _Message(
          icon: Icons.info_outline,
          text:
              'This verification step is not supported by Protea. '
              'Please use emoji verification.',
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
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => request.acceptVerification(),
            child: const Text('Accept'),
          ),
        ];
      case KeyVerificationState.askChoice:
        return [
          TextButton(onPressed: _cancelAndClose, child: const Text('Cancel')),
          FilledButton(
            onPressed: () => request.continueVerification(EventTypes.Sas),
            child: const Text('Compare emojis'),
          ),
        ];
      case KeyVerificationState.askSas:
        return [
          TextButton(
            onPressed: () async {
              await request.rejectSas();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text("They don't match"),
          ),
          FilledButton(
            onPressed: () => request.acceptSas(),
            child: const Text('They match'),
          ),
        ];
      case KeyVerificationState.waitingAccept:
      case KeyVerificationState.waitingSas:
        return [
          TextButton(onPressed: _cancelAndClose, child: const Text('Cancel')),
        ];
      case KeyVerificationState.done:
      case KeyVerificationState.error:
        return [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ];
      case KeyVerificationState.askSSSS:
        return [
          TextButton(
            onPressed: _ssssBusy ? null : () => request.openSSSS(skip: true),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: _ssssBusy ? null : _openSSSS,
            child: _ssssBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unlock'),
          ),
        ];
      case KeyVerificationState.showQRSuccess:
      case KeyVerificationState.confirmQRScan:
        return [
          TextButton(onPressed: _cancelAndClose, child: const Text('Cancel')),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify device'),
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
