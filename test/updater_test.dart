import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import 'package:protea/src/updater.dart';

Map<String, Object?> _releaseJson(
  String tag, {
  bool prerelease = false,
  bool draft = false,
  List<Map<String, Object?>> assets = const [],
}) => {
  'tag_name': tag,
  'name': 'Protea $tag',
  'body': 'Notes for $tag',
  'draft': draft,
  'prerelease': prerelease,
  'html_url': 'https://github.com/$updateRepository/releases/tag/$tag',
  'published_at': '2026-11-01T12:00:00Z',
  'assets': assets,
};

Release _release(String tag, {bool prerelease = false}) =>
    Release.fromGitHubJson(_releaseJson(tag, prerelease: prerelease))!;

/// A release zip shaped like the one tool/package-linux.sh produces.
List<int> _releaseZip() {
  const folder = 'protea-1.2.0-linux-x64';
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('$folder/install-linux.sh', '#!/bin/bash\n')
        ..mode = 0x1ed, // 0755
    )
    ..addFile(
      ArchiveFile.bytes('$folder/protea/protea', [0x7f, 0x45, 0x4c, 0x46])
        ..mode = 0x1ed,
    )
    ..addFile(
      ArchiveFile.string(
        '$folder/protea/data/flutter_assets/version.json',
        '{}',
      ),
    );
  return ZipEncoder().encodeBytes(archive);
}

bool get _isRoot =>
    Platform.isLinux &&
    (Process.runSync('id', ['-u']).stdout as String).trim() == '0';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'protea',
    packageName: 'protea',
    version: '1.1.0',
    buildNumber: '7',
    buildSignature: '',
  );

  group('AppVersion', () {
    test('parses tags and pubspec versions, ignoring build metadata', () {
      expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('1.2.3+45'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('1.2.3-beta.1')!.preRelease, ['beta', '1']);
      expect(AppVersion.tryParse('v1.2.3-rc.2')!.toString(), '1.2.3-rc.2');
      expect(AppVersion.tryParse('nightly'), isNull);
      expect(AppVersion.tryParse('1.2'), isNull);
    });

    test('orders by semver precedence', () {
      final ordered = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
        '1.0.1',
        '1.10.0',
        '2.0.0',
      ].map((v) => AppVersion.tryParse(v)!).toList();
      for (var i = 0; i < ordered.length - 1; i++) {
        expect(
          ordered[i] < ordered[i + 1],
          isTrue,
          reason: '${ordered[i]} < ${ordered[i + 1]}',
        );
      }
      expect([...ordered.reversed]..sort(), ordered);
    });

    test('automatic dev builds sit between two stable releases', () {
      // tool/release-version.sh names development builds after the next
      // stable version: 1.0.1-dev.N follows 1.0.0 and precedes 1.0.1.
      AppVersion v(String s) => AppVersion.tryParse(s)!;
      expect(v('1.0.1-dev.6') > v('1.0.0'), isTrue);
      expect(v('1.0.1-dev.6') < v('1.0.1'), isTrue);
      expect(v('1.0.1-dev.10') > v('1.0.1-dev.9'), isTrue);
    });
  });

  group('Release.fromGitHubJson', () {
    test('skips drafts and tags that are not versions', () {
      expect(
        Release.fromGitHubJson(_releaseJson('v1.0.0', draft: true)),
        isNull,
      );
      expect(Release.fromGitHubJson(_releaseJson('nightly')), isNull);
      expect(Release.fromGitHubJson(_releaseJson('v1.0.0')), isNotNull);
    });

    test('a pre-release tag counts as pre-release even when not flagged', () {
      expect(_release('v1.2.0-beta.1').preRelease, isTrue);
      expect(_release('v1.2.0', prerelease: true).preRelease, isTrue);
      expect(_release('v1.2.0').preRelease, isFalse);
    });

    test('reads assets with their SHA-256 digest', () {
      final release = Release.fromGitHubJson(
        _releaseJson(
          'v1.2.0',
          assets: [
            {
              'name': 'protea-1.2.0-linux-x64.zip',
              'browser_download_url': 'https://example.com/linux.zip',
              'size': 1234,
              'digest': 'sha256:ABCDEF',
            },
            {
              'name': 'protea-1.2.0-windows-x64.zip',
              'browser_download_url': 'https://example.com/windows.zip',
              'size': 99,
            },
          ],
        ),
      )!;
      final linux = release.assetFor('-linux-x64.zip')!;
      expect(linux.size, 1234);
      expect(linux.sha256, 'abcdef');
      expect(release.assetFor('-windows-x64.zip')!.sha256, isNull);
      expect(release.assetFor('-macos.zip'), isNull);
    });
  });

  group('pickUpdate', () {
    final releases = [
      _release('v1.0.0'),
      _release('v1.1.0'),
      _release('v1.1.1'),
      _release('v1.2.0-beta.1', prerelease: true),
    ];

    test('offers the newest stable release', () {
      final update = pickUpdate(
        releases,
        AppVersion.tryParse('1.1.0')!,
        includePreReleases: false,
      );
      expect(update?.tag, 'v1.1.1');
    });

    test('offers pre-releases on the beta channel', () {
      final update = pickUpdate(
        releases,
        AppVersion.tryParse('1.1.0')!,
        includePreReleases: true,
      );
      expect(update?.tag, 'v1.2.0-beta.1');
    });

    test('never offers a downgrade', () {
      // A beta user who switches back to stable stays on the beta until a
      // newer stable release comes out.
      expect(
        pickUpdate(
          releases,
          AppVersion.tryParse('1.2.0-beta.1')!,
          includePreReleases: false,
        ),
        isNull,
      );
      expect(
        pickUpdate(
          releases,
          AppVersion.tryParse('1.1.1')!,
          includePreReleases: false,
        ),
        isNull,
      );
    });
  });

  test('release archive suffix per platform', () {
    expect(releaseAssetSuffix(Abi.linuxX64), '-linux-x64.zip');
    expect(releaseAssetSuffix(Abi.windowsX64), '-windows-x64.zip');
    expect(releaseAssetSuffix(Abi.macosArm64), '-macos.zip');
    expect(releaseAssetSuffix(Abi.androidArm64), isNull);
  });

  group('detectInstallKind', () {
    InstallKind linux(String exe, {bool flatpak = false, bool pkexec = true}) =>
        detectInstallKind(
          operatingSystem: 'linux',
          executable: exe,
          environment: {'HOME': '/home/ann'},
          isFlatpak: flatpak,
          hasPkexec: pkexec,
        );

    InstallKind windows(String exe) => detectInstallKind(
      operatingSystem: 'windows',
      executable: exe,
      environment: {
        'LocalAppData': r'C:\Users\Ann\AppData\Local',
        'ProgramFiles': r'C:\Program Files',
      },
    );

    test('recognises the install-linux.sh locations', () {
      expect(
        linux('/home/ann/.local/opt/protea/protea'),
        InstallKind.linuxUser,
      );
      expect(linux('/opt/protea/protea'), InstallKind.linuxSystem);
      expect(linux('/opt/protea/protea', pkexec: false), InstallKind.manual);
      expect(
        linux('/home/ann/src/Protea/build/linux/x64/release/bundle/protea'),
        InstallKind.manual,
      );
      expect(linux('/app/protea/protea', flatpak: true), InstallKind.manual);
    });

    test('resolves symlinked home directories', () {
      final kind = detectInstallKind(
        operatingSystem: 'linux',
        executable: '/var/home/ann/.local/opt/protea/protea',
        environment: {'HOME': '/home/ann'},
        canonicalize: (path) => path.replaceFirst('/home/', '/var/home/'),
      );
      expect(kind, InstallKind.linuxUser);
    });

    test('recognises the install-windows.ps1 locations', () {
      expect(
        windows(r'C:\Users\Ann\AppData\Local\Programs\Protea\protea.exe'),
        InstallKind.windowsUser,
      );
      expect(
        windows(r'c:\users\ann\appdata\local\programs\protea\protea.exe'),
        InstallKind.windowsUser,
      );
      expect(
        windows(r'C:\Program Files\Protea\protea.exe'),
        InstallKind.windowsAllUsers,
      );
      expect(windows(r'D:\Tools\Protea\protea.exe'), InstallKind.manual);
    });

    test('other platforms update by hand', () {
      expect(
        detectInstallKind(
          operatingSystem: 'macos',
          executable: '/Applications/protea.app/Contents/MacOS/protea',
          environment: const {},
        ),
        InstallKind.manual,
      );
    });
  });

  group('Updater', () {
    Updater updaterServing(
      List<Map<String, Object?>> releases, {
      int status = 200,
    }) => Updater(
      installKind: InstallKind.linuxUser,
      httpClient: () => MockClient((request) async {
        expect(request.url.host, 'api.github.com');
        expect(request.url.path, '/repos/$updateRepository/releases');
        expect(request.headers['User-Agent'], startsWith('Protea/'));
        return http.Response(jsonEncode(releases), status);
      }),
    );

    test('check offers the newest release of the chosen channel', () async {
      final updater = updaterServing([
        _releaseJson('v1.0.0'),
        _releaseJson('v1.2.0'),
        _releaseJson('v1.3.0-beta.1', prerelease: true),
      ]);
      final stable = await updater.check(includePreReleases: false);
      expect(stable?.tag, 'v1.2.0');
      expect(updater.status, UpdateStatus.available);

      final beta = await updater.check(includePreReleases: true);
      expect(beta?.tag, 'v1.3.0-beta.1');
    });

    test('check reports being up to date', () async {
      final updater = updaterServing([
        _releaseJson('v1.0.0'),
        _releaseJson('v1.1.0'),
      ]);
      expect(await updater.check(includePreReleases: true), isNull);
      expect(updater.status, UpdateStatus.upToDate);
    });

    test('a rate-limited check fails without offering anything', () async {
      final updater = updaterServing([], status: 403);
      expect(await updater.check(includePreReleases: false), isNull);
      expect(updater.status, UpdateStatus.checkFailed);
      expect(updater.error, contains('rate limit'));
    });

    test('only installs in place where the install location allows it', () {
      final release = Release.fromGitHubJson(
        _releaseJson(
          'v1.2.0',
          assets: [
            for (final suffix in [
              '-linux-x64.zip',
              '-windows-x64.zip',
              '-macos.zip',
            ])
              {
                'name': 'protea-1.2.0$suffix',
                'browser_download_url': 'https://example.com/a$suffix',
              },
          ],
        ),
      )!;
      expect(
        Updater(installKind: InstallKind.linuxUser).canInstall(release),
        releaseAssetSuffix() != null,
      );
      expect(
        Updater(installKind: InstallKind.manual).canInstall(release),
        isFalse,
      );
      expect(
        Updater(
          installKind: InstallKind.linuxUser,
        ).canInstall(_release('v1.2.0')),
        isFalse,
        reason: 'no archive for this platform',
      );
    });

    group('prepare', () {
      late Directory staging;
      setUp(() async {
        staging = await Directory.systemTemp.createTemp('protea-update-test-');
      });
      tearDown(() => staging.delete(recursive: true));

      ReleaseAsset asset(List<int> zip, {String? digest}) => ReleaseAsset(
        name: 'protea-1.2.0-linux-x64.zip',
        downloadUrl: Uri.parse(
          'https://example.com/protea-1.2.0-linux-x64.zip',
        ),
        size: zip.length,
        sha256: digest ?? sha256.convert(zip).toString(),
      );

      Updater serving(List<int> zip) => Updater(
        installKind: InstallKind.linuxUser,
        httpClient: () =>
            MockClient((_) async => http.Response.bytes(zip, 200)),
      );

      test('downloads, verifies and extracts the release package', () async {
        final zip = _releaseZip();
        final updater = serving(zip);
        final progress = <double?>[];
        updater.addListener(() => progress.add(updater.progress));

        final package = await updater.prepare(
          asset(zip),
          staging,
          windows: false,
        );

        expect(p.basename(package.installer), 'install-linux.sh');
        expect(
          p.basename(p.dirname(package.installer)),
          'protea-1.2.0-linux-x64',
        );
        final executable = File(p.join(package.bundle, 'protea'));
        expect(executable.existsSync(), isTrue);
        if (Platform.isLinux || Platform.isMacOS) {
          expect(
            executable.statSync().mode & 0x49,
            isNot(0),
            reason: 'executable bit kept',
          );
        }
        expect(
          File(p.join(staging.path, 'protea-1.2.0-linux-x64.zip')).existsSync(),
          isFalse,
        );
        expect(progress, contains(1.0));
        expect(updater.status, UpdateStatus.installing);
      });

      test('rejects a download whose checksum does not match', () async {
        final zip = _releaseZip();
        await expectLater(
          serving(
            zip,
          ).prepare(asset(zip, digest: '0' * 64), staging, windows: false),
          throwsA(isA<UpdateException>()),
        );
      });

      test('rejects an archive without an installer', () async {
        final zip = ZipEncoder().encodeBytes(
          Archive()..addFile(ArchiveFile.string('README.txt', 'hi')),
        );
        await expectLater(
          serving(zip).prepare(asset(zip), staging, windows: false),
          throwsA(isA<UpdateException>()),
        );
      });
    });
  });

  group('Linux update helper', skip: !Platform.isLinux || _isRoot, () {
    late Directory root;
    late Directory home;
    late Directory staging;
    late String log;
    late String result;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('protea-helper-test-');
      home = Directory(p.join(root.path, 'home'))..createSync();
      staging = Directory(p.join(root.path, 'staging'))..createSync();
      log = p.join(root.path, 'update.log');
      result = p.join(root.path, 'update-result.json');
    });
    tearDown(() => root.delete(recursive: true));

    /// Runs the helper as if Protea (an already-exited process) had handed
    /// over to it, with HOME pointing into the temp directory.
    Future<void> runHelper(
      String installer,
      String bundle,
      String executable,
    ) async {
      final script = File(p.join(staging.path, 'apply-update.sh'))
        ..writeAsStringSync(linuxUpdateHelper);
      final app = await Process.start('true', []);
      await app.exitCode;
      final run = await Process.run(
        '/bin/bash',
        [
          script.path,
          '${app.pid}',
          installer,
          bundle,
          executable,
          'user',
          log,
          result,
          staging.path,
          '1.2.0',
        ],
        environment: {'HOME': home.path, 'PATH': Platform.environment['PATH']!},
        includeParentEnvironment: false,
      );
      expect(run.exitCode, 0, reason: '${run.stderr}');
    }

    Future<String> waitForFile(String path) async {
      for (var i = 0; i < 100 && !File(path).existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return File(path).readAsStringSync();
    }

    File executableScript(String path, String body) {
      final file = File(path)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('#!/bin/sh\n$body\n');
      Process.runSync('chmod', ['+x', path]);
      return file;
    }

    test('installs with install-linux.sh and starts the new version', () async {
      final package = Directory(
        p.join(staging.path, 'extracted', 'protea-1.2.0-linux-x64'),
      )..createSync(recursive: true);
      final installer = File(
        'install-linux.sh',
      ).copySync(p.join(package.path, 'install-linux.sh'));
      final bundle = p.join(package.path, 'protea');
      final launched = p.join(root.path, 'launched');
      executableScript(p.join(bundle, 'protea'), 'echo "\$0" > "$launched"');
      File(p.join(bundle, 'protea.png')).writeAsBytesSync([0]);
      final installDir = p.join(home.path, '.local', 'opt', 'protea');

      await runHelper(installer.path, bundle, p.join(installDir, 'protea'));

      expect(jsonDecode(File(result).readAsStringSync()), {
        'version': '1.2.0',
        'status': 0,
      });
      expect(File(p.join(installDir, 'protea')).existsSync(), isTrue);
      expect(
        File(
          p.join(
            home.path,
            '.local',
            'share',
            'applications',
            'energy.vgt.protea.desktop',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(staging.existsSync(), isFalse, reason: 'staging cleaned up');
      expect(
        (await waitForFile(launched)).trim(),
        p.join(installDir, 'protea'),
      );
      expect(File(log).readAsStringSync(), contains('installer exited with 0'));
    });

    test('records a failed install and starts the old version again', () async {
      final installer = executableScript(
        p.join(staging.path, 'install.sh'),
        'exit 3',
      );
      final launched = p.join(root.path, 'launched');
      final old = executableScript(
        p.join(root.path, 'old', 'protea'),
        'echo old > "$launched"',
      );

      await runHelper(installer.path, staging.path, old.path);

      expect(jsonDecode(File(result).readAsStringSync()), {
        'version': '1.2.0',
        'status': 3,
      });
      expect((await waitForFile(launched)).trim(), 'old');
    });
  });
}
