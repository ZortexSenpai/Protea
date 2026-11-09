#!/usr/bin/env bash
#
# Protea Linux installer / updater.
#
# Works from a release zip (this script next to a protea/ folder) or from a
# source checkout (after `flutter build linux --release`). Running it again
# updates an existing installation in place. Chat data is never touched.
#
#   ./install-linux.sh                 install or update for the current user
#   sudo ./install-linux.sh            install or update system-wide
#   ./install-linux.sh --uninstall     remove the app (keeps chat data)
#   ./install-linux.sh --bundle DIR    use DIR instead of the default locations

set -euo pipefail

APP_NAME="Protea"
APP_ID="energy.vgt.protea"
BIN_NAME="protea"
COMMENT="A cross-platform Matrix chat client built with Flutter"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Install locations: system-wide when root, per-user otherwise -----------
# NOTE: the app stores chat data in ~/.local/share/protea (its XDG data dir),
# so the app files must live somewhere else — never install into that path.
if [[ ${EUID} -eq 0 ]]; then
  INSTALL_DIR="/opt/${BIN_NAME}"
  DESKTOP_DIR="/usr/share/applications"
  BIN_LINK_DIR="/usr/local/bin"
else
  INSTALL_DIR="${HOME}/.local/opt/${BIN_NAME}"
  DESKTOP_DIR="${HOME}/.local/share/applications"
  BIN_LINK_DIR="${HOME}/.local/bin"
fi
DESKTOP_FILE="${DESKTOP_DIR}/${APP_ID}.desktop"
BIN_LINK="${BIN_LINK_DIR}/${BIN_NAME}"
DATA_DIR="${HOME}/.local/share/${BIN_NAME}"

# --- Argument parsing --------------------------------------------------------
BUNDLE_DIR=""
UNINSTALL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall) UNINSTALL=1; shift ;;
    --bundle)    BUNDLE_DIR="${2:?--bundle requires a path}"; shift 2 ;;
    -h|--help)   sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
done

refresh_databases() {
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
}

# Versions before v1.0 installed the app files into the data directory.
# Remove only the app files from there; anything else is user data.
remove_legacy_install() {
  [[ ${EUID} -eq 0 || "${INSTALL_DIR}" == "${DATA_DIR}" ]] && return 0
  if [[ -x "${DATA_DIR}/${BIN_NAME}" && -d "${DATA_DIR}/lib" ]]; then
    echo "Cleaning up old installation in ${DATA_DIR} (chat data is kept) ..."
    rm -rf "${DATA_DIR}/${BIN_NAME}" "${DATA_DIR}/lib" "${DATA_DIR}/data" \
           "${DATA_DIR}/${BIN_NAME}.png"
  fi
}

# --- Uninstall ---------------------------------------------------------------
if [[ ${UNINSTALL} -eq 1 ]]; then
  echo "Removing ${APP_NAME} from ${INSTALL_DIR} ..."
  rm -rf "${INSTALL_DIR}"
  rm -f "${DESKTOP_FILE}" "${BIN_LINK}"
  remove_legacy_install
  refresh_databases
  echo "${APP_NAME} uninstalled."
  echo "Chat data in ${DATA_DIR} was kept; delete that folder to remove it too."
  exit 0
fi

# --- Locate the application bundle --------------------------------------------
# 1. --bundle DIR   2. protea/ next to this script (release zip)
# 3. build/linux/<arch>/release/bundle (source checkout)
if [[ -z "${BUNDLE_DIR}" ]]; then
  if [[ -x "${SCRIPT_DIR}/${BIN_NAME}/${BIN_NAME}" ]]; then
    BUNDLE_DIR="${SCRIPT_DIR}/${BIN_NAME}"
  else
    for arch in x64 arm64; do
      candidate="${SCRIPT_DIR}/build/linux/${arch}/release/bundle"
      [[ -x "${candidate}/${BIN_NAME}" ]] && BUNDLE_DIR="${candidate}" && break
    done
  fi
fi
if [[ -z "${BUNDLE_DIR}" || ! -x "${BUNDLE_DIR}/${BIN_NAME}" ]]; then
  echo "Error: application bundle not found." >&2
  echo "Expected a '${BIN_NAME}/' folder next to this script (release zip)" >&2
  echo "or build/linux/<arch>/release/bundle (run: flutter build linux --release)." >&2
  exit 1
fi

# Icon: bundled protea.png (release zip), else repo logo (source checkout)
ICON_SRC=""
for c in "${BUNDLE_DIR}/${BIN_NAME}.png" "${SCRIPT_DIR}/logo_transparent.png" \
         "${SCRIPT_DIR}/logo.png"; do
  [[ -f "$c" ]] && ICON_SRC="$c" && break
done

# --- Install / update the application folder -----------------------------------
if [[ -d "${INSTALL_DIR}" ]]; then
  echo "Updating ${APP_NAME} in ${INSTALL_DIR} ..."
else
  echo "Installing ${APP_NAME} to ${INSTALL_DIR} ..."
fi
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
cp -a "${BUNDLE_DIR}/." "${INSTALL_DIR}/"
chmod +x "${INSTALL_DIR}/${BIN_NAME}"

ICON_LINE=""
if [[ -n "${ICON_SRC}" ]]; then
  cp "${ICON_SRC}" "${INSTALL_DIR}/${BIN_NAME}.png"
  ICON_LINE="Icon=${INSTALL_DIR}/${BIN_NAME}.png"
fi

remove_legacy_install

# --- Desktop entry -------------------------------------------------------------
echo "Creating desktop entry ${DESKTOP_FILE} ..."
mkdir -p "${DESKTOP_DIR}"
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Comment=${COMMENT}
Exec=${INSTALL_DIR}/${BIN_NAME}
${ICON_LINE}
Terminal=false
Categories=Network;InstantMessaging;Chat;
Keywords=matrix;chat;messenger;
StartupWMClass=${BIN_NAME}
EOF
chmod 644 "${DESKTOP_FILE}"
refresh_databases

# --- Command-line symlink --------------------------------------------------------
mkdir -p "${BIN_LINK_DIR}"
ln -sf "${INSTALL_DIR}/${BIN_NAME}" "${BIN_LINK}"

command -v desktop-file-validate >/dev/null 2>&1 && \
  desktop-file-validate "${DESKTOP_FILE}" || true

echo
echo "${APP_NAME} installed successfully."
echo "  Application: ${INSTALL_DIR}"
echo "  Launcher:    ${DESKTOP_FILE}"
echo "  Command:     ${BIN_LINK}"
echo "It should now appear in your application menu (log out/in if it doesn't)."
