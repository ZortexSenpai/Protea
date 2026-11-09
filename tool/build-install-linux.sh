#!/usr/bin/env bash
#
# Build the Linux release bundle and install it on this machine.
#
# The install itself is done by install-linux.sh, so it behaves exactly like
# installing from a release zip: running it again updates the installation in
# place and chat data is never touched.
#
#   tool/build-install-linux.sh              build + install for the current user
#   tool/build-install-linux.sh --system     build + install system-wide (sudo)
#   tool/build-install-linux.sh --no-build   install an already-built release bundle

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_NAME="protea"
APP_NAME="Protea"

BUILD=1
SYSTEM=0
for arg in "$@"; do
  case "${arg}" in
    --no-build) BUILD=0 ;;
    --system)   SYSTEM=1 ;;
    -h|--help)  sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: ${arg} (see --help)" >&2; exit 1 ;;
  esac
done

# Building as root would leave root-owned files in build/ and .dart_tool/;
# use --system instead, which only elevates the install step.
if [[ ${EUID} -eq 0 ]]; then
  echo "Error: don't run this script as root; use --system to install system-wide." >&2
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

# --- Install -------------------------------------------------------------------
INSTALLER="${REPO_DIR}/install-linux.sh"
if [[ ${SYSTEM} -eq 1 ]]; then
  sudo bash "${INSTALLER}" --bundle "${BUNDLE_DIR}"
else
  bash "${INSTALLER}" --bundle "${BUNDLE_DIR}"
fi

if pgrep -x "${BIN_NAME}" >/dev/null 2>&1; then
  echo
  echo "Note: ${APP_NAME} is still running; restart it to use the new build."
fi
