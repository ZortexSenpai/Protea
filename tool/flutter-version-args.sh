#!/usr/bin/env bash
#
# Prints the `flutter build` arguments that stamp version information into a
# build, one per line; the build scripts in tool/ and the release workflow
# pass them on. The app shows them under Settings > About and compares the
# version against GitHub releases when checking for updates.
#
#   PROTEA_VERSION       full version, e.g. 1.2.0 or v1.2.0-beta.1 (from the
#                        release tag); defaults to pubspec.yaml's version
#   PROTEA_BUILD_NUMBER  build number (the CI run number); defaults to
#                        pubspec.yaml's +build part
#   PROTEA_COMMIT        commit hash; defaults to the checkout's HEAD
#
# Example: flutter build linux --release $(tool/flutter-version-args.sh)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${PROTEA_VERSION:-}" ]]; then
  version="${PROTEA_VERSION#v}"
  if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
    echo "Error: PROTEA_VERSION '${PROTEA_VERSION}' is not MAJOR.MINOR.PATCH[-pre]." >&2
    exit 1
  fi
  # Platform version fields are numeric, so the build name drops a
  # pre-release suffix; the app reads the full version from the define.
  echo "--build-name=${version%%-*}"
  echo "--dart-define=PROTEA_VERSION=${version}"
fi

if [[ -n "${PROTEA_BUILD_NUMBER:-}" ]]; then
  if [[ ! "${PROTEA_BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
    echo "Error: PROTEA_BUILD_NUMBER '${PROTEA_BUILD_NUMBER}' is not a number." >&2
    exit 1
  fi
  echo "--build-number=${PROTEA_BUILD_NUMBER}"
  echo "--dart-define=PROTEA_BUILD=${PROTEA_BUILD_NUMBER}"
fi

commit="${PROTEA_COMMIT:-$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || true)}"
if [[ -n "${commit}" ]]; then
  echo "--dart-define=PROTEA_COMMIT=${commit}"
fi
