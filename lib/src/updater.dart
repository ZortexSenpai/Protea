import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:archive/archive_io.dart' show extractFileToDisk;
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart' show Logs;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'build_info.dart';
import 'settings.dart';

/// GitHub repository whose releases Protea updates from.
const updateRepository = 'ZortexSenpai/Protea';

final releasesPageUrl = Uri.https('github.com', '/$updateRepository/releases');

/// A semantic version (`1.2.0`, `1.2.0-beta.1`), ordered by the semver
/// precedence rules — so `1.2.0-beta.1 < 1.2.0-beta.2 < 1.2.0-rc.1 < 1.2.0`.
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(
    this.major,
    this.minor,
    this.patch, [
    this.preRelease = const [],
  ]);

  final int major;
  final int minor;
  final int patch;

  /// Dot-separated pre-release identifiers (`['beta', '1']`); empty for a
  /// release.
  final List<String> preRelease;

  static final _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );
  static final _numeric = RegExp(r'^\d+$');

  /// Parses `1.2.3`, `v1.2.3`, `1.2.3-beta.1` and ignores `+build` metadata.
  static AppVersion? tryParse(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      match[4]?.split('.') ?? const [],
    );
  }

  bool get isPreRelease => preRelease.isNotEmpty;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    // A release ranks above all of its pre-releases.
    if (preRelease.isEmpty || other.preRelease.isEmpty) {
      if (preRelease.isEmpty == other.preRelease.isEmpty) return 0;
      return preRelease.isEmpty ? 1 : -1;
    }
    for (
      var i = 0;
      i < math.min(preRelease.length, other.preRelease.length);
      i++
    ) {
      final a = preRelease[i];
      final b = other.preRelease[i];
      final aNumeric = _numeric.hasMatch(a);
      final bNumeric = _numeric.hasMatch(b);
      final order = switch ((aNumeric, bNumeric)) {
        (true, true) => int.parse(a).compareTo(int.parse(b)),
        // Numeric identifiers rank below alphanumeric ones.
        (true, false) => -1,
        (false, true) => 1,
        (false, false) => a.compareTo(b),
      };
      if (order != 0) return order;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode =>
      Object.hash(major, minor, patch, Object.hashAll(preRelease));

  @override
  String toString() => [
    '$major.$minor.$patch',
    if (preRelease.isNotEmpty) preRelease.join('.'),
  ].join('-');
}

/// A downloadable file attached to a [Release].
@immutable
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    this.size = 0,
    this.sha256,
  });

  final String name;
  final Uri downloadUrl;
  final int size;

  /// Lower-case hex SHA-256 GitHub computed for the upload, when it lists one.
  final String? sha256;

  factory ReleaseAsset.fromGitHubJson(Map<String, Object?> json) {
    final digest = json['digest'];
    return ReleaseAsset(
      name: json['name'] as String,
      downloadUrl: Uri.parse(json['browser_download_url'] as String),
      size: (json['size'] as num?)?.toInt() ?? 0,
      sha256: digest is String && digest.startsWith('sha256:')
          ? digest.substring('sha256:'.length).toLowerCase()
          : null,
    );
  }
}

/// A published GitHub release of Protea.
@immutable
class Release {
  const Release({
    required this.version,
    required this.tag,
    required this.name,
    required this.notes,
    required this.preRelease,
    required this.pageUrl,
    this.publishedAt,
    this.assets = const [],
  });

  final AppVersion version;
  final String tag;
  final String name;

  /// Release notes as written on GitHub (Markdown).
  final String notes;
  final bool preRelease;
  final Uri pageUrl;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  /// Parses one entry of GitHub's list-releases response. Drafts and tags
  /// that aren't versions give null.
  static Release? fromGitHubJson(Map<String, Object?> json) {
    if (json['draft'] == true) return null;
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;
    final name = json['name'];
    return Release(
      version: version,
      tag: tag,
      name: name is String && name.trim().isNotEmpty ? name : tag,
      notes: (json['body'] as String?)?.trim() ?? '',
      // A tag with a pre-release suffix is never offered as stable, even if
      // the release wasn't flagged on GitHub.
      preRelease: json['prerelease'] == true || version.isPreRelease,
      pageUrl:
          Uri.tryParse(json['html_url'] as String? ?? '') ?? releasesPageUrl,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      assets: [
        for (final asset in json['assets'] as List? ?? const [])
          if (asset is Map<String, Object?>) ReleaseAsset.fromGitHubJson(asset),
      ],
    );
  }

  /// The asset whose file name ends in [suffix] (see [releaseAssetSuffix]).
  ReleaseAsset? assetFor(String? suffix) {
    if (suffix == null) return null;
    for (final asset in assets) {
      if (asset.name.endsWith(suffix)) return asset;
    }
    return null;
  }
}

/// The newest of [releases] that is newer than [current], or null when
/// [current] is up to date. Pre-releases only count with
/// [includePreReleases].
Release? pickUpdate(
  Iterable<Release> releases,
  AppVersion current, {
  required bool includePreReleases,
}) {
  Release? best;
  for (final release in releases) {
    if (release.preRelease && !includePreReleases) continue;
    if (!(release.version > current)) continue;
    if (best == null || release.version > best.version) best = release;
  }
  return best;
}

/// File-name suffix of this platform's release archive, as `tool/package-*`
/// and the release workflow name them; null where no archive is published.
String? releaseAssetSuffix([Abi? abi]) => switch (abi ?? Abi.current()) {
  Abi.linuxX64 => '-linux-x64.zip',
  Abi.linuxArm64 => '-linux-arm64.zip',
  Abi.windowsX64 => '-windows-x64.zip',
  Abi.windowsArm64 => '-windows-arm64.zip',
  Abi.macosX64 || Abi.macosArm64 => '-macos.zip',
  _ => null,
};

/// How the running copy of Protea was installed, which decides whether it
/// can replace itself.
enum InstallKind {
  /// `install-linux.sh` as a normal user (`~/.local/opt/protea`).
  linuxUser,

  /// `sudo install-linux.sh` (`/opt/protea`); updated through pkexec.
  linuxSystem,

  /// `install-windows.ps1` (`%LOCALAPPDATA%\Programs\Protea`).
  windowsUser,

  /// `install-windows.ps1 -AllUsers` (`%ProgramFiles%\Protea`); the
  /// installer runs elevated through a UAC prompt.
  windowsAllUsers,

  /// Anything else — Flatpak, macOS, mobile, a build run from the source
  /// tree, a hand-copied folder. The user installs updates themselves.
  manual;

  bool get canSelfUpdate => this != manual;

  /// Whether installing asks for administrator rights.
  bool get needsElevation => this == linuxSystem || this == windowsAllUsers;
}

/// Works out the [InstallKind] from where the executable lives, mirroring
/// the locations `install-linux.sh` and `install-windows.ps1` install to.
///
/// [canonicalize] resolves symlinks in a directory path (e.g. Silverblue's
/// `/home` → `/var/home`) so it compares equal to the resolved executable.
InstallKind detectInstallKind({
  required String operatingSystem,
  required String executable,
  required Map<String, String> environment,
  bool isFlatpak = false,
  bool hasPkexec = false,
  String Function(String path) canonicalize = _identity,
}) {
  switch (operatingSystem) {
    case 'linux':
      if (isFlatpak) return InstallKind.manual;
      final dir = p.posix.dirname(executable);
      final home = environment['HOME'];
      if (home != null &&
          p.posix.equals(
            dir,
            canonicalize(p.posix.join(home, '.local', 'opt', 'protea')),
          )) {
        return InstallKind.linuxUser;
      }
      if (p.posix.equals(dir, canonicalize('/opt/protea'))) {
        return hasPkexec ? InstallKind.linuxSystem : InstallKind.manual;
      }
    case 'windows':
      final dir = p.windows.dirname(executable);
      String? env(String name) {
        // Windows environment names are case-insensitive.
        for (final entry in environment.entries) {
          if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
        }
        return null;
      }

      final localAppData = env('LOCALAPPDATA');
      if (localAppData != null &&
          p.windows.equals(
            dir,
            p.windows.join(localAppData, 'Programs', 'Protea'),
          )) {
        return InstallKind.windowsUser;
      }
      final programFiles = env('ProgramFiles');
      if (programFiles != null &&
          p.windows.equals(dir, p.windows.join(programFiles, 'Protea'))) {
        return InstallKind.windowsAllUsers;
      }
  }
  return InstallKind.manual;
}

String _identity(String path) => path;

/// Finds the installer script and the application folder in an extracted
/// release archive: `protea-<version>-<os>-<arch>/install-<os>.*` next to a
/// `protea/` folder holding the executable.
({String installer, String bundle})? locateReleasePackage(
  String root, {
  required bool windows,
}) {
  final installerName = windows ? 'install-windows.ps1' : 'install-linux.sh';
  final executableName = windows ? 'protea.exe' : 'protea';
  final candidates = [
    root,
    for (final entry in Directory(root).listSync())
      if (entry is Directory) entry.path,
  ];
  for (final dir in candidates) {
    final installer = p.join(dir, installerName);
    final bundle = p.join(dir, 'protea');
    if (File(installer).existsSync() &&
        File(p.join(bundle, executableName)).existsSync()) {
      return (installer: installer, bundle: bundle);
    }
  }
  return null;
}

/// What the update helper reported after the previous run of Protea exited
/// to install an update.
@immutable
class UpdateOutcome {
  const UpdateOutcome({
    required this.version,
    required this.succeeded,
    required this.logPath,
  });

  final String version;
  final bool succeeded;
  final String logPath;
}

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  checkFailed,
  installFailed,
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Checks GitHub for newer releases and installs them in place where the
/// install location allows it (see [InstallKind]).
///
/// Installing downloads the platform's release zip, verifies it against
/// GitHub's SHA-256 digest, extracts it, and hands over to a small helper
/// script that waits for Protea to exit, runs the bundled installer (the
/// same `install-linux.sh` / `install-windows.ps1` users run by hand, so
/// chat data is never touched) and starts the new version.
class Updater extends ChangeNotifier {
  Updater({http.Client Function()? httpClient, InstallKind? installKind})
    : _httpClient = httpClient ?? http.Client.new,
      _installKindOverride = installKind;

  /// The app-wide instance; its state outlives the settings dialog.
  static final instance = Updater();

  final http.Client Function() _httpClient;
  final InstallKind? _installKindOverride;

  UpdateStatus _status = UpdateStatus.idle;
  UpdateStatus get status => _status;

  /// The release offered as an update, once a check found one.
  Release? _update;
  Release? get update => _update;

  /// Download progress from 0 to 1, or null while unknown.
  double? _progress;
  double? get progress => _progress;

  String? _error;
  String? get error => _error;

  bool get busy => switch (_status) {
    UpdateStatus.checking ||
    UpdateStatus.downloading ||
    UpdateStatus.installing => true,
    _ => false,
  };

  /// Whether startup and periodic background checks run on this platform.
  /// Mobile builds aren't published as release assets, so they don't nag.
  static bool get supportsAutoCheck =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  InstallKind? _installKind;
  InstallKind get installKind =>
      _installKind ??= _installKindOverride ?? _detect();

  static InstallKind _detect() {
    if (kIsWeb) return InstallKind.manual;
    try {
      return detectInstallKind(
        operatingSystem: Platform.operatingSystem,
        executable: Platform.resolvedExecutable,
        environment: Platform.environment,
        isFlatpak:
            Platform.environment.containsKey('FLATPAK_ID') ||
            File('/.flatpak-info').existsSync(),
        hasPkexec:
            Platform.isLinux &&
            (File('/usr/bin/pkexec').existsSync() ||
                File('/bin/pkexec').existsSync()),
        canonicalize: (path) {
          try {
            return Directory(path).resolveSymbolicLinksSync();
          } catch (_) {
            return path;
          }
        },
      );
    } catch (e, s) {
      Logs().w('Could not determine how Protea was installed', e, s);
      return InstallKind.manual;
    }
  }

  /// This platform's archive in [release], if it has one.
  ReleaseAsset? assetFor(Release release) =>
      kIsWeb ? null : release.assetFor(releaseAssetSuffix());

  /// Whether [release] can be installed from inside the app.
  bool canInstall(Release release) =>
      installKind.canSelfUpdate && assetFor(release) != null;

  void _set(UpdateStatus status, {String? error, double? progress}) {
    _status = status;
    _error = error;
    _progress = progress;
    notifyListeners();
  }

  /// Looks for a release newer than the running build. Returns it, or null
  /// when up to date or when the check failed (see [error]).
  Future<Release?> check({required bool includePreReleases}) async {
    if (busy) return _update;
    _set(UpdateStatus.checking);
    try {
      final info = await BuildInfo.current();
      final current =
          AppVersion.tryParse(info.version) ?? const AppVersion(0, 0, 0);
      final releases = await _fetchReleases(info);
      _update = pickUpdate(
        releases,
        current,
        includePreReleases: includePreReleases,
      );
      _set(_update == null ? UpdateStatus.upToDate : UpdateStatus.available);
    } catch (e, s) {
      Logs().w('Update check failed', e, s);
      _update = null;
      _set(UpdateStatus.checkFailed, error: _describe(e));
    }
    return _update;
  }

  Future<List<Release>> _fetchReleases(BuildInfo info) async {
    final client = _httpClient();
    try {
      final response = await client
          .get(
            Uri.https('api.github.com', '/repos/$updateRepository/releases', {
              'per_page': '30',
            }),
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'Protea/${info.version}',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const UpdateException(
          'GitHub rate limit reached, try again later',
        );
      }
      if (response.statusCode != 200) {
        throw UpdateException('GitHub answered HTTP ${response.statusCode}');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! List) {
        throw const UpdateException('Unexpected response from GitHub');
      }
      return [
        for (final entry in body)
          if (entry is Map<String, Object?>) ?Release.fromGitHubJson(entry),
      ];
    } finally {
      client.close();
    }
  }

  /// Downloads and installs [update], then quits so the helper can replace
  /// the app. Only returns when something failed (see [error]).
  Future<void> install() async {
    final release = _update;
    if (release == null || busy) return;
    final asset = assetFor(release);
    final kind = installKind;
    if (asset == null || !kind.canSelfUpdate) return;

    Directory? staging;
    try {
      // A fresh private (0700) directory: the helper script is run from
      // here, possibly as root, so it must not be somewhere others can write.
      staging = await Directory.systemTemp.createTemp('protea-update-');
      final package = await prepare(
        asset,
        staging,
        windows: Platform.isWindows,
      );

      final support = await getApplicationSupportDirectory();
      await support.create(recursive: true);
      final log = p.join(support.path, 'update.log');
      final result = p.join(support.path, _resultFileName);
      try {
        await File(result).delete();
      } on FileSystemException {
        // No outcome left over from an earlier update.
      }

      await _startHelper(
        kind: kind,
        staging: staging.path,
        installer: package.installer,
        bundle: package.bundle,
        log: log,
        result: result,
        version: release.version.toString(),
      );
    } catch (e, s) {
      Logs().e('Installing the update failed', e, s);
      _set(UpdateStatus.installFailed, error: _describe(e));
      try {
        await staging?.delete(recursive: true);
      } catch (_) {}
      return;
    }
    await _quit();
  }

  /// Downloads [asset] into [staging], verifies and extracts it, and finds
  /// the installer and app folder in it. Moves through
  /// [UpdateStatus.downloading] to [UpdateStatus.installing].
  @visibleForTesting
  Future<({String installer, String bundle})> prepare(
    ReleaseAsset asset,
    Directory staging, {
    required bool windows,
  }) async {
    _set(UpdateStatus.downloading, progress: 0);
    final archive = File(p.join(staging.path, p.basename(asset.name)));
    await _download(asset, archive);

    _set(UpdateStatus.installing);
    final extracted = p.join(staging.path, 'extracted');
    await _verifyAndExtract(archive.path, extracted, asset.sha256);
    await archive.delete();

    final package = locateReleasePackage(extracted, windows: windows);
    if (package == null) {
      throw const UpdateException('The download contains no installer');
    }
    return package;
  }

  Future<void> _download(ReleaseAsset asset, File target) async {
    final client = _httpClient();
    final info = await BuildInfo.current();
    try {
      final request = http.Request('GET', asset.downloadUrl)
        ..headers['User-Agent'] = 'Protea/${info.version}'
        ..headers['Accept'] = 'application/octet-stream';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw UpdateException('Download failed: HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? asset.size;
      final sink = target.openWrite();
      var received = 0;
      try {
        // Per-chunk timeout: a stalled connection fails instead of hanging.
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final progress = math.min(received / total, 1.0);
            if (progress - (_progress ?? 0) >= 0.01 || progress == 1) {
              _set(UpdateStatus.downloading, progress: progress);
            }
          }
        }
      } finally {
        await sink.close();
      }
      if (asset.size > 0 && received != asset.size) {
        throw const UpdateException('The download was incomplete');
      }
    } finally {
      client.close();
    }
  }

  Future<void> _startHelper({
    required InstallKind kind,
    required String staging,
    required String installer,
    required String bundle,
    required String log,
    required String result,
    required String version,
  }) async {
    final executable = Platform.resolvedExecutable;
    if (Platform.isWindows) {
      final script = p.join(staging, 'apply-update.ps1');
      await File(script).writeAsString(windowsUpdateHelper);
      await startWindowsUpdateHelper(
        script,
        appPid: pid,
        installer: installer,
        bundle: bundle,
        executable: executable,
        log: log,
        result: result,
        staging: staging,
        version: version,
        allUsers: kind == InstallKind.windowsAllUsers,
      );
    } else {
      final script = p.join(staging, 'apply-update.sh');
      await File(script).writeAsString(linuxUpdateHelper);
      await Process.start('/bin/bash', [
        script,
        '$pid',
        installer,
        bundle,
        executable,
        kind == InstallKind.linuxSystem ? 'system' : 'user',
        log,
        result,
        staging,
        version,
      ], mode: ProcessStartMode.detached);
    }
  }

  /// Quits the way the tray menu does; the exit is the helper's cue.
  Future<void> _quit() async {
    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {}
    // destroy() ends the process on desktop; this covers the window plugin
    // being unavailable.
    Timer(const Duration(seconds: 3), () => exit(0));
  }

  static const _resultFileName = 'update-result.json';

  /// The outcome the helper left behind if the previous run quit to install
  /// an update; null otherwise. Reading it consumes it.
  static Future<UpdateOutcome?> takeLastOutcome() async {
    if (kIsWeb) return null;
    try {
      final support = await getApplicationSupportDirectory();
      final file = File(p.join(support.path, _resultFileName));
      if (!await file.exists()) return null;
      final raw = (await file.readAsString()).replaceFirst('﻿', '');
      await file.delete();
      final json = jsonDecode(raw) as Map<String, Object?>;
      final version = json['version'] as String;
      final info = await BuildInfo.current();
      return UpdateOutcome(
        version: version,
        // The installer can exit cleanly without the running build being the
        // new one (e.g. it installed somewhere else); that's a failure too.
        succeeded:
            json['status'] == 0 &&
            AppVersion.tryParse(info.version) == AppVersion.tryParse(version),
        logPath: p.join(support.path, 'update.log'),
      );
    } catch (e, s) {
      Logs().w('Could not read the last update outcome', e, s);
      return null;
    }
  }

  Timer? _initialCheck;
  Timer? _periodicCheck;

  /// Checks in the background while [AppSettings.autoCheckUpdates] is on: a
  /// little after startup and then hourly, each time only if the last check
  /// is a day old. [onUpdate] is told about each update found.
  void startAutoCheck(
    AppSettings settings, {
    required void Function(Release release) onUpdate,
  }) {
    if (!supportsAutoCheck || _periodicCheck != null) return;
    Future<void> tick() async {
      if (!settings.autoCheckUpdates || busy) return;
      final last = settings.lastUpdateCheck;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(hours: 24)) {
        return;
      }
      final release = await check(includePreReleases: settings.betaUpdates);
      if (_status == UpdateStatus.checkFailed) return; // retry next tick
      await settings.setLastUpdateCheck(DateTime.now());
      if (release != null) onUpdate(release);
    }

    _initialCheck = Timer(const Duration(seconds: 20), tick);
    _periodicCheck = Timer.periodic(const Duration(hours: 1), (_) => tick());
  }

  @override
  void dispose() {
    _initialCheck?.cancel();
    _periodicCheck?.cancel();
    super.dispose();
  }

  static String _describe(Object error) => switch (error) {
    UpdateException(:final message) => message,
    TimeoutException() => 'The connection timed out',
    SocketException() || http.ClientException() => 'No connection to GitHub',
    _ => error.toString(),
  };
}

/// Checks the archive against [expectedSha256] (when GitHub lists one) and
/// extracts it — on a background isolate, both are a few seconds of CPU.
Future<void> _verifyAndExtract(
  String archive,
  String destination,
  String? expectedSha256,
) => Isolate.run(() async {
  if (expectedSha256 != null) {
    final digest = await sha256.bind(File(archive).openRead()).first;
    if (digest.toString() != expectedSha256) {
      throw const UpdateException(
        'The download is damaged (checksum mismatch)',
      );
    }
  }
  await extractFileToDisk(archive, destination);
});

/// Starts [windowsUpdateHelper], saved as [script], so that it outlives
/// Protea: it waits for [appPid] to exit before it installs.
@visibleForTesting
Future<Process> startWindowsUpdateHelper(
  String script, {
  required int appPid,
  required String installer,
  required String bundle,
  required String executable,
  required String log,
  required String result,
  required String staging,
  required String version,
  bool allUsers = false,
}) async {
  // Not ProcessStartMode.detached: on Windows that creates the process
  // without a console (DETACHED_PROCESS), and Windows PowerShell exits
  // straight away without one, before running a line of the script. A
  // normal child gets a console without a window and keeps running after
  // Protea exits all the same.
  final helper = await Process.start(
    'powershell.exe',
    [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      script,
      '-AppPid',
      '$appPid',
      '-Installer',
      installer,
      '-Bundle',
      bundle,
      '-Executable',
      executable,
      '-Log',
      log,
      '-Result',
      result,
      '-Staging',
      staging,
      '-Version',
      version,
      if (allUsers) '-AllUsers',
    ],
    // Anywhere but Protea's own working directory, which is the install
    // folder when it was started from the Start Menu: Windows can't delete a
    // folder that is a running process's current directory, so the installer
    // would fail halfway through replacing it.
    workingDirectory: Directory.systemTemp.path,
  );
  // Nothing reads the helper's output; draining it keeps the pipes from
  // filling up while Protea is still running.
  unawaited(helper.stdout.drain<void>());
  unawaited(helper.stderr.drain<void>());
  return helper;
}

/// Waits for Protea to exit, runs the bundled install-linux.sh (through
/// pkexec for a system-wide install), records the outcome and starts Protea
/// again — the old version if the install failed or was cancelled.
@visibleForTesting
const linuxUpdateHelper = r'''#!/bin/bash
# Written by Protea's updater. Arguments:
#   PID INSTALLER BUNDLE EXECUTABLE MODE(user|system) LOG RESULT STAGING VERSION
pid="$1" installer="$2" bundle="$3" executable="$4" mode="$5"
log="$6" result="$7" staging="$8" version="$9"
exec >>"$log" 2>&1
echo "=== $(date '+%F %T') updating to ${version} (${mode} install)"

# Give Protea up to a minute to shut down, then make sure it is gone.
for _ in $(seq 1 300); do
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.2
done
if kill -0 "$pid" 2>/dev/null; then
  echo "Protea did not exit, stopping it"
  kill "$pid" 2>/dev/null; sleep 2; kill -9 "$pid" 2>/dev/null
fi

if [ "$mode" = system ]; then
  pkexec /bin/bash "$installer" --bundle "$bundle"
else
  /bin/bash "$installer" --bundle "$bundle"
fi
status=$?
echo "installer exited with ${status}"
printf '{"version":"%s","status":%d}\n' "$version" "$status" > "$result"

rm -rf "$staging"
"$executable" >/dev/null 2>&1 </dev/null &
disown
''';

/// The Windows counterpart of [linuxUpdateHelper]: runs the bundled
/// install-windows.ps1, elevated through UAC for an all-users install.
@visibleForTesting
const windowsUpdateHelper = r'''# Written by Protea's updater.
param(
    [int] $AppPid,
    [string] $Installer,
    [string] $Bundle,
    [string] $Executable,
    [string] $Log,
    [string] $Result,
    [string] $Staging,
    [string] $Version,
    [switch] $AllUsers
)
$ErrorActionPreference = 'Continue'
function Write-Log([string] $line) {
    Add-Content -Path $Log -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $line"
}
Write-Log "=== updating to $Version"

# Give Protea up to a minute to shut down, then make sure it is gone.
$app = Get-Process -Id $AppPid -ErrorAction SilentlyContinue
if ($app -and -not $app.WaitForExit(60000)) {
    Write-Log 'Protea did not exit, stopping it'
    Stop-Process -Id $AppPid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

$status = 1
try {
    if ($AllUsers) {
        # Elevated processes can't have their output redirected; the
        # installer's own messages are lost, its exit code is not.
        $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$Installer`" -Bundle `"$Bundle`" -AllUsers"
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine `
            -Verb RunAs -WindowStyle Hidden -Wait -PassThru
        $status = $proc.ExitCode
    } else {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Installer -Bundle $Bundle 2>&1 |
            ForEach-Object { Write-Log "$_" }
        $status = $LASTEXITCODE
    }
} catch {
    Write-Log "installer did not run: $_"
}
Write-Log "installer exited with $status"
[IO.File]::WriteAllText($Result, "{""version"":""$Version"",""status"":$status}")

try {
    # Started from its own folder, as the Start Menu shortcut does.
    Start-Process -FilePath $Executable -WorkingDirectory (Split-Path -Parent $Executable) -ErrorAction Stop
} catch {
    Write-Log "could not start Protea again: $_"
}
Remove-Item -Recurse -Force -Path $Staging -ErrorAction SilentlyContinue
''';
