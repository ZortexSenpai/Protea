#!/usr/bin/env bash
#
# Build the Linux release bundle and package it as a distributable zip.
#
# The zip contains one folder (protea-<version>-linux-<arch>/) with
# install-linux.sh and the protea/ application folder — users extract it and
# run ./install-linux.sh to install or update Protea.
#
#   tool/package-linux.sh              build + package
#   tool/package-linux.sh --no-build   package an already-built release bundle

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_NAME="protea"
APP_NAME="Protea"

BUILD=1
[[ "${1:-}" == "--no-build" ]] && BUILD=0

command -v zip >/dev/null 2>&1 || {
  echo "Error: 'zip' is required (Fedora: sudo dnf install zip)." >&2; exit 1; }

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

# --- Package -------------------------------------------------------------------
# A release build's version (PROTEA_VERSION, from the tag) wins over pubspec.yaml.
VERSION="${PROTEA_VERSION:-$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' "${REPO_DIR}/pubspec.yaml")}"
VERSION="${VERSION#v}"
PKG_NAME="${BIN_NAME}-${VERSION:-unknown}-linux-${ARCH}"
DIST_DIR="${REPO_DIR}/dist"
STAGING="${DIST_DIR}/${PKG_NAME}"
ZIP_PATH="${DIST_DIR}/${PKG_NAME}.zip"

echo "Packaging ${PKG_NAME}.zip ..."
rm -rf "${STAGING}" "${ZIP_PATH}"
mkdir -p "${STAGING}"

cp -a "${BUNDLE_DIR}" "${STAGING}/${BIN_NAME}"
cp "${REPO_DIR}/logo_transparent.png" "${STAGING}/${BIN_NAME}/${BIN_NAME}.png"
cp "${REPO_DIR}/install-linux.sh" "${STAGING}/install-linux.sh"
chmod +x "${STAGING}/install-linux.sh" "${STAGING}/${BIN_NAME}/${BIN_NAME}"

cat > "${STAGING}/README.txt" <<EOF
${APP_NAME} ${VERSION} for Linux (${ARCH})

To install or update, open a terminal in this folder and run:

    ./install-linux.sh

To install for all users:            sudo ./install-linux.sh
To uninstall (chat data is kept):    ./install-linux.sh --uninstall
EOF

(cd "${DIST_DIR}" && zip -qry "${PKG_NAME}.zip" "${PKG_NAME}")
rm -rf "${STAGING}"

echo "Done: ${ZIP_PATH} ($(du -h "${ZIP_PATH}" | cut -f1))"
