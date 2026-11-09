#!/usr/bin/env bash
#
# Build the Linux release bundle and package it as a Flatpak.
#
# Uses flatpak/energy.vgt.protea.yml and exports a single-file bundle to
# dist/protea-<version>-linux-<arch>.flatpak that installs with
# `flatpak install <file>`.
#
#   tool/build-flatpak.sh              build + package
#   tool/build-flatpak.sh --no-build   package an already-built release bundle
#   tool/build-flatpak.sh --install    build + package + install for this user
#
# Requires flatpak plus flatpak-builder — either the native package
# (Fedora: sudo dnf install flatpak-builder) or the Flathub app
# (flatpak install flathub org.flatpak.Builder). The freedesktop runtime
# is pulled from Flathub automatically on the first build.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="energy.vgt.protea"
BIN_NAME="protea"
APP_NAME="Protea"
MANIFEST="${REPO_DIR}/flatpak/${APP_ID}.yml"

BUILD=1
INSTALL=0
for arg in "$@"; do
  case "${arg}" in
    --no-build) BUILD=0 ;;
    --install)  INSTALL=1 ;;
    -h|--help)  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: ${arg} (see --help)" >&2; exit 1 ;;
  esac
done

command -v flatpak >/dev/null 2>&1 || {
  echo "Error: 'flatpak' is required (Fedora: sudo dnf install flatpak)." >&2; exit 1; }

if command -v flatpak-builder >/dev/null 2>&1; then
  FLATPAK_BUILDER=(flatpak-builder)
elif flatpak info org.flatpak.Builder >/dev/null 2>&1; then
  FLATPAK_BUILDER=(flatpak run org.flatpak.Builder)
else
  echo "Error: flatpak-builder not found. Install it with either:" >&2
  echo "  sudo dnf install flatpak-builder" >&2
  echo "  flatpak install flathub org.flatpak.Builder" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64)  ARCH=x64 ;;
  aarch64) ARCH=arm64 ;;
  *) echo "Error: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac
BUNDLE_DIR="${REPO_DIR}/build/linux/${ARCH}/release/bundle"

# --- Build ---------------------------------------------------------------------
if [[ ${BUILD} -eq 1 ]]; then
  # rustup/cargo are needed to compile the vodozemac bindings
  [[ -d "${HOME}/.cargo/bin" ]] && export PATH="${HOME}/.cargo/bin:${PATH}"

  if command -v flutter >/dev/null 2>&1; then
    FLUTTER=flutter
  elif [[ -x "${HOME}/development/flutter/bin/flutter" ]]; then
    FLUTTER="${HOME}/development/flutter/bin/flutter"
  else
    echo "Error: flutter not found on PATH (or in ~/development/flutter)." >&2
    exit 1
  fi
  # Version, build number and commit for Settings > About (see the script).
  VERSION_ARGS=($("${REPO_DIR}/tool/flutter-version-args.sh"))
  echo "Building ${APP_NAME} (linux ${ARCH}, release) ..."
  (cd "${REPO_DIR}" && "${FLUTTER}" build linux --release \
    ${VERSION_ARGS[@]+"${VERSION_ARGS[@]}"})
fi

[[ -x "${BUNDLE_DIR}/${BIN_NAME}" ]] || {
  echo "Error: release bundle not found at ${BUNDLE_DIR}." >&2; exit 1; }

# --- Stage the bundle where the manifest's `dir` source expects it -------------
STAGE="${REPO_DIR}/build/flatpak"
rm -rf "${STAGE}/bundle"
mkdir -p "${STAGE}/bundle"
cp -a "${BUNDLE_DIR}/." "${STAGE}/bundle/"

# --- flatpak-builder ------------------------------------------------------------
echo "Building Flatpak (this pulls the freedesktop runtime on first run) ..."
"${FLATPAK_BUILDER[@]}" \
  --force-clean --user --install-deps-from=flathub \
  --state-dir="${STAGE}/.flatpak-builder" \
  --repo="${STAGE}/repo" \
  "${STAGE}/builddir" "${MANIFEST}"

# --- Export a distributable single-file bundle -----------------------------------
# A release build's version (PROTEA_VERSION, from the tag) wins over pubspec.yaml.
VERSION="${PROTEA_VERSION:-$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' "${REPO_DIR}/pubspec.yaml")}"
VERSION="${VERSION#v}"
DIST_DIR="${REPO_DIR}/dist"
FLATPAK_PATH="${DIST_DIR}/${BIN_NAME}-${VERSION:-unknown}-linux-${ARCH}.flatpak"
mkdir -p "${DIST_DIR}"
flatpak build-bundle \
  --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
  "${STAGE}/repo" "${FLATPAK_PATH}" "${APP_ID}"
echo "Done: ${FLATPAK_PATH} ($(du -h "${FLATPAK_PATH}" | cut -f1))"

if [[ ${INSTALL} -eq 1 ]]; then
  echo "Installing for the current user ..."
  flatpak install --user -y --reinstall "${FLATPAK_PATH}"
  echo "Installed. Run with: flatpak run ${APP_ID}"
fi
