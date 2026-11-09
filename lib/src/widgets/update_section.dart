import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../build_info.dart';
import '../l10n.dart';
import '../settings.dart';
import '../updater.dart';

/// The About settings page: what this build is, and checking for and
/// installing updates.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.settings, this.updater});

  final AppSettings settings;

  /// Defaults to [Updater.instance]; tests pass their own.
  final Updater? updater;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BuildInfoTile(),
        const Divider(height: 32),
        UpdatePanel(settings: settings, updater: updater),
        const SizedBox(height: 8),
        if (Updater.supportsAutoCheck)
          SwitchListTile(
            secondary: const Icon(Icons.update),
            title: Text(l10n.autoCheckUpdatesTitle),
            subtitle: Text(l10n.autoCheckUpdatesDescription),
            value: settings.autoCheckUpdates,
            onChanged: settings.setAutoCheckUpdates,
          ),
        SwitchListTile(
          secondary: const Icon(Icons.science_outlined),
          title: Text(l10n.betaUpdatesTitle),
          subtitle: Text(l10n.betaUpdatesDescription),
          value: settings.betaUpdates,
          onChanged: (value) async {
            await settings.setBetaUpdates(value);
            // Refresh an earlier answer so it matches the new channel.
            final updater = this.updater ?? Updater.instance;
            if (updater.status != UpdateStatus.idle && !updater.busy) {
              unawaited(updater.check(includePreReleases: value));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.open_in_new),
          title: Text(l10n.allReleases),
          onTap: () =>
              launchUrl(releasesPageUrl, mode: LaunchMode.externalApplication),
        ),
      ],
    );
  }
}

class _BuildInfoTile extends StatelessWidget {
  const _BuildInfoTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return FutureBuilder<BuildInfo>(
      future: BuildInfo.current(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null ? null : AppVersion.tryParse(info.version);
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'logo.png',
              width: 48,
              height: 48,
              cacheWidth: 144,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.info_outline, size: 40),
            ),
          ),
          title: Row(
            children: [
              Text(l10n.appTitle, style: theme.textTheme.titleMedium),
              if (version?.isPreRelease ?? false) ...[
                const SizedBox(width: 8),
                _BetaChip(),
              ],
            ],
          ),
          subtitle: info == null
              ? null
              : SelectableText.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${l10n.versionLabel} ${info.version}'),
                      if (info.buildNumber.isNotEmpty)
                        TextSpan(
                          text: ' · ${l10n.buildLabel} ${info.buildNumber}',
                        ),
                      if (info.shortCommit != null)
                        TextSpan(
                          text: ' · ${l10n.commitLabel} ${info.shortCommit}',
                        ),
                      if (!BuildInfo.isReleaseBuild)
                        TextSpan(text: ' · ${l10n.localBuild}'),
                    ],
                  ),
                ),
          trailing: info == null
              ? null
              : IconButton(
                  tooltip: l10n.copyVersionInfo,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: info.details));
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(content: Text(l10n.copiedToClipboard)),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _BetaChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        context.l10n.preReleaseBadge,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}

/// "Check for updates" with the result: up to date, the release on offer
/// with its notes and an install (or download) button, or progress while
/// it installs.
class UpdatePanel extends StatelessWidget {
  const UpdatePanel({super.key, required this.settings, this.updater});

  final AppSettings settings;
  final Updater? updater;

  @override
  Widget build(BuildContext context) {
    final updater = this.updater ?? Updater.instance;
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final l10n = context.l10n;
        final theme = Theme.of(context);
        final status = updater.status;
        final release = updater.update;
        final showRelease =
            release != null &&
            switch (status) {
              UpdateStatus.available ||
              UpdateStatus.downloading ||
              UpdateStatus.installing ||
              UpdateStatus.installFailed => true,
              _ => false,
            };

        final statusLine = switch (status) {
          UpdateStatus.idle => null,
          UpdateStatus.checking => l10n.checkingForUpdates,
          UpdateStatus.upToDate => l10n.upToDate,
          UpdateStatus.available => null,
          UpdateStatus.downloading => l10n.downloadingUpdate(
            ((updater.progress ?? 0) * 100).round(),
          ),
          UpdateStatus.installing => l10n.installingUpdate,
          UpdateStatus.checkFailed => l10n.updateCheckFailed(
            updater.error ?? '',
          ),
          UpdateStatus.installFailed => l10n.updateInstallFailed(
            updater.error ?? '',
          ),
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FilledButton.tonalIcon(
                    icon: status == UpdateStatus.checking
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(l10n.checkForUpdates),
                    onPressed: updater.busy
                        ? null
                        : () => updater.check(
                            includePreReleases: settings.betaUpdates,
                          ),
                  ),
                  if (status == UpdateStatus.upToDate) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              if (statusLine != null && !showRelease) ...[
                const SizedBox(height: 8),
                Text(
                  statusLine,
                  style: status == UpdateStatus.checkFailed
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
              ],
              if (showRelease) ...[
                const SizedBox(height: 12),
                _ReleaseCard(
                  release: release,
                  updater: updater,
                  statusLine: statusLine,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.release,
    required this.updater,
    required this.statusLine,
  });

  final Release release;
  final Updater updater;
  final String? statusLine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = updater.status;
    final canInstall = updater.canInstall(release);
    final asset = updater.assetFor(release);
    final published = release.publishedAt;

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.new_releases_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.updateAvailable(release.version.toString()),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (release.preRelease) ...[
                  const SizedBox(width: 8),
                  _BetaChip(),
                ],
                if (published != null) ...[
                  const Spacer(),
                  Text(
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(published.toLocal()),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            if (release.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: SelectableText(
                    release.notes,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            if (!canInstall) ...[
              const SizedBox(height: 12),
              Text(l10n.updateManualInstall, style: theme.textTheme.bodySmall),
            ] else if (updater.installKind.needsElevation) ...[
              const SizedBox(height: 12),
              Text(l10n.updateNeedsAdmin, style: theme.textTheme.bodySmall),
            ],
            if (status == UpdateStatus.downloading ||
                status == UpdateStatus.installing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: status == UpdateStatus.downloading
                    ? updater.progress
                    : null,
              ),
            ],
            if (statusLine != null) ...[
              const SizedBox(height: 8),
              Text(
                statusLine!,
                style: status == UpdateStatus.installFailed
                    ? TextStyle(color: theme.colorScheme.error)
                    : theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canInstall)
                  FilledButton.icon(
                    icon: const Icon(Icons.system_update_alt),
                    label: Text(l10n.installAndRestart),
                    onPressed: updater.busy ? null : updater.install,
                  )
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: Text(l10n.downloadUpdate),
                    onPressed: () => launchUrl(
                      asset?.downloadUrl ?? release.pageUrl,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => launchUrl(
                    release.pageUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(l10n.releaseNotes),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The update panel on its own, for the "update available" notice.
Future<void> showUpdateDialog(BuildContext context, AppSettings settings) =>
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.checkForUpdates),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(child: UpdatePanel(settings: settings)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );

/// Startup hooks: reports how an update installed on the previous run went,
/// and starts the background checks that announce new releases.
void announceUpdates({
  required GlobalKey<NavigatorState> navigatorKey,
  required AppSettings settings,
}) {
  unawaited(_reportLastOutcome(navigatorKey));
  Updater.instance.startAutoCheck(
    settings,
    onUpdate: (release) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      _showSnackBar(
        context,
        SnackBar(
          content: Text(
            context.l10n.updateAvailable(release.version.toString()),
          ),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: context.l10n.viewUpdate,
            onPressed: () {
              final context = navigatorKey.currentContext;
              if (context != null) showUpdateDialog(context, settings);
            },
          ),
        ),
      );
    },
  );
}

Future<void> _reportLastOutcome(GlobalKey<NavigatorState> navigatorKey) async {
  final outcome = await Updater.takeLastOutcome();
  if (outcome == null) return;
  // Let the first page (and its Scaffold) settle before saying anything.
  await Future<void>.delayed(const Duration(seconds: 2));
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  final l10n = context.l10n;
  if (outcome.succeeded) {
    _showSnackBar(
      context,
      SnackBar(content: Text(l10n.updatedTo(outcome.version))),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.error_outline),
      title: Text(l10n.updateFailedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.updateFailedBody(outcome.version)),
          const SizedBox(height: 8),
          SelectableText(
            outcome.logPath,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              launchUrl(releasesPageUrl, mode: LaunchMode.externalApplication),
          child: Text(l10n.allReleases),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}

void _showSnackBar(BuildContext context, SnackBar snackBar) {
  try {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);
  } catch (_) {
    // No Scaffold on screen to show it in; the notice isn't essential.
  }
}
