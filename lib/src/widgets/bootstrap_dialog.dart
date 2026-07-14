import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

/// Walks through cross-signing and online key backup setup:
/// - fresh accounts get cross-signing, secret storage and key backup with a
///   newly generated recovery key,
/// - existing setups are unlocked with the recovery key, verifying this
///   session and downloading the key backup.
Future<void> showBootstrapDialog(
  BuildContext context, {
  required Client client,
  bool wipe = false,
}) => showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => BootstrapDialog(client: client, wipe: wipe),
);

class BootstrapDialog extends StatefulWidget {
  const BootstrapDialog({super.key, required this.client, this.wipe = false});

  final Client client;

  /// When true, existing cross-signing keys and backups are discarded and
  /// set up from scratch.
  final bool wipe;

  @override
  State<BootstrapDialog> createState() => _BootstrapDialogState();
}

class _BootstrapDialogState extends State<BootstrapDialog> {
  Bootstrap? _bootstrap;
  final _recoveryKeyController = TextEditingController();
  String? _recoveryKeyToShow;
  bool _recoveryKeySaved = false;
  bool _busy = false;
  bool _advancing = false;
  String? _unlockError;

  @override
  void initState() {
    super.initState();
    _bootstrap = widget.client.encryption?.bootstrap(
      onUpdate: (bootstrap) {
        if (!mounted) return;
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _autoAdvance(bootstrap),
        );
      },
    );
    final bootstrap = _bootstrap;
    if (bootstrap != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _autoAdvance(bootstrap),
      );
    }
  }

  @override
  void dispose() {
    _recoveryKeyController.dispose();
    super.dispose();
  }

  /// Answers all states that need no user input. The remaining states
  /// (unlock, done, error) render UI instead.
  Future<void> _autoAdvance(Bootstrap bootstrap) async {
    if (!mounted || _advancing) return;
    _advancing = true;
    try {
      switch (bootstrap.state) {
        case BootstrapState.askWipeSsss:
          bootstrap.wipeSsss(widget.wipe);
        case BootstrapState.askUseExistingSsss:
          bootstrap.useExistingSsss(!widget.wipe);
        case BootstrapState.askBadSsss:
          bootstrap.ignoreBadSecrets(true);
        case BootstrapState.askNewSsss:
          await bootstrap.newSsss();
          _recoveryKeyToShow = bootstrap.newSsssKey?.recoveryKey;
        case BootstrapState.askWipeCrossSigning:
          bootstrap.wipeCrossSigning(widget.wipe);
        case BootstrapState.askSetupCrossSigning:
          await bootstrap.askSetupCrossSigning(
            setupMasterKey: true,
            setupSelfSigningKey: true,
            setupUserSigningKey: true,
          );
        case BootstrapState.askWipeOnlineKeyBackup:
          bootstrap.wipeOnlineKeyBackup(widget.wipe);
        case BootstrapState.askSetupOnlineKeyBackup:
          await bootstrap.askSetupOnlineKeyBackup(true);
        case BootstrapState.loading:
        case BootstrapState.askUnlockSsss:
        case BootstrapState.openExistingSsss:
        case BootstrapState.error:
        case BootstrapState.done:
          break;
      }
    } catch (e) {
      if (mounted) setState(() => _unlockError = e.toString());
    } finally {
      _advancing = false;
      if (mounted) setState(() {});
    }
  }

  /// Unlocks existing secret storage with the entered recovery key and
  /// self-signs this session.
  Future<void> _unlock() async {
    final bootstrap = _bootstrap;
    final key = _recoveryKeyController.text.trim();
    if (bootstrap == null || key.isEmpty) return;
    setState(() {
      _busy = true;
      _unlockError = null;
    });
    try {
      if (bootstrap.state == BootstrapState.openExistingSsss) {
        await bootstrap.newSsssKey!.unlock(keyOrPassphrase: key);
        await bootstrap.openExistingSsss();
      } else {
        for (final ssssKey in bootstrap.oldSsssKeys!.values) {
          await ssssKey.unlock(keyOrPassphrase: key);
        }
        bootstrap.unlockedSsss();
      }
      try {
        await widget.client.encryption?.crossSigning.selfSign(
          keyOrPassphrase: key,
        );
      } catch (_) {}
    } catch (_) {
      if (mounted) {
        setState(
          () => _unlockError =
              'Could not unlock the backup. Please check the recovery key.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _body(BuildContext context) {
    final bootstrap = _bootstrap;
    if (bootstrap == null) {
      return const Text('End-to-end encryption is not available.');
    }
    switch (bootstrap.state) {
      case BootstrapState.askUnlockSsss:
      case BootstrapState.openExistingSsss:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your recovery key to unlock the chat backup and verify '
              'this session. You got the recovery key when the backup was '
              'set up (it looks like: EsT* ****…).',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _recoveryKeyController,
              enabled: !_busy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Recovery key',
                border: const OutlineInputBorder(),
                errorText: _unlockError,
              ),
              onSubmitted: (_) => _unlock(),
            ),
          ],
        );
      case BootstrapState.done:
        final recoveryKey = _recoveryKeyToShow;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user, color: Color(0xFF43A047)),
                SizedBox(width: 8),
                Expanded(child: Text('Chat backup is set up!')),
              ],
            ),
            if (recoveryKey != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Save this recovery key somewhere safe (e.g. a password '
                'manager). You will need it to read your encrypted message '
                'history on new devices:',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        recoveryKey,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: recoveryKey)),
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I saved my recovery key'),
                value: _recoveryKeySaved,
                onChanged: (value) =>
                    setState(() => _recoveryKeySaved = value ?? false),
              ),
            ],
          ],
        );
      case BootstrapState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.gpp_bad_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(_unlockError ?? 'Setting up the backup failed.'),
          ],
        );
      default:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Setting up…'),
          ],
        );
    }
  }

  List<Widget> _actions(BuildContext context) {
    final bootstrap = _bootstrap;
    switch (bootstrap?.state) {
      case null:
      case BootstrapState.error:
        return [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ];
      case BootstrapState.askUnlockSsss:
      case BootstrapState.openExistingSsss:
        return [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy ? null : _unlock,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unlock'),
          ),
        ];
      case BootstrapState.done:
        return [
          FilledButton(
            onPressed: _recoveryKeyToShow == null || _recoveryKeySaved
                ? () => Navigator.of(context).pop()
                : null,
            child: const Text('Done'),
          ),
        ];
      default:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chat backup'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _body(context),
      ),
      actions: _actions(context),
    );
  }
}
