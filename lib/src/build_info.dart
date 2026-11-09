import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What the running build is: its version, build number and commit.
///
/// Release builds made by `.github/workflows/release.yml` pass all three with
/// `--dart-define` — the version in full, since a pre-release suffix such as
/// `-beta.1` doesn't survive the platforms' numeric version fields. Local
/// builds fall back to the `version:` in pubspec.yaml as the platform reports
/// it; the build scripts in `tool/` add the commit.
@immutable
class BuildInfo {
  const BuildInfo({
    required this.version,
    required this.buildNumber,
    this.commit,
  });

  /// Semantic version, e.g. `1.2.0` or `1.2.0-beta.1`.
  final String version;

  /// CI run number for release builds, the pubspec build number otherwise.
  /// Empty when unknown.
  final String buildNumber;

  /// Git commit the build was made from, when the build passed one.
  final String? commit;

  static const _definedVersion = String.fromEnvironment('PROTEA_VERSION');
  static const _definedBuild = String.fromEnvironment('PROTEA_BUILD');
  static const _definedCommit = String.fromEnvironment('PROTEA_COMMIT');

  /// Whether this build came out of the release pipeline (rather than a
  /// local `flutter build` / `flutter run`).
  static bool get isReleaseBuild => _definedVersion.isNotEmpty;

  // The value rather than its Future is cached: a completed Future runs its
  // listeners in the zone it was created in, which in widget tests is a
  // previous test's (dead) fake-async zone.
  static BuildInfo? _current;

  /// The running build, resolved once.
  static Future<BuildInfo> current() async => _current ??= await _load();

  static Future<BuildInfo> _load() async {
    var version = _definedVersion;
    var build = _definedBuild;
    if (version.isEmpty || build.isEmpty) {
      try {
        final info = await PackageInfo.fromPlatform();
        if (version.isEmpty) version = info.version;
        if (build.isEmpty) build = info.buildNumber;
      } catch (_) {
        // No version metadata (e.g. under `flutter test`).
      }
    }
    return BuildInfo(
      version: version.isEmpty ? '0.0.0' : version,
      buildNumber: build,
      commit: _definedCommit.isEmpty ? null : _definedCommit,
    );
  }

  /// The commit shortened to the usual seven characters.
  String? get shortCommit =>
      commit == null || commit!.length <= 7 ? commit : commit!.substring(0, 7);

  /// `1.2.0 (build 57)`, or just the version when there is no build number.
  String get label =>
      buildNumber.isEmpty ? version : '$version (build $buildNumber)';

  /// One line for bug reports, e.g.
  /// `Protea 1.2.0 (build 57) · a1b2c3d · linux x64`.
  String get details => [
    'Protea $label',
    ?shortCommit,
    if (!isReleaseBuild) 'local build',
    '${Platform.operatingSystem} ${_architecture()}',
  ].join(' · ');

  static String _architecture() {
    // Abi names read like `linux_x64`; the OS is already in the line.
    final abi = Abi.current().toString();
    final underscore = abi.indexOf('_');
    return underscore < 0 ? abi : abi.substring(underscore + 1);
  }
}
