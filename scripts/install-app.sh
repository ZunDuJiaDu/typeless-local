#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/Applications}"
APP_NAME="Typeless"
APP_PATH="$(${ROOT_DIR}/scripts/build-app.sh)"
DESTINATION="${INSTALL_DIR}/${APP_NAME}.app"
SYSTEM_APP="/Applications/${APP_NAME}.app"
USER_APP="${HOME}/Applications/${APP_NAME}.app"

bundle_id() {
  local app_path="$1"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${app_path}/Contents/Info.plist" 2>/dev/null || true
}

mkdir -p "${INSTALL_DIR}"
rm -rf "${DESTINATION}"
cp -R "${APP_PATH}" "${DESTINATION}"
printf '%s\n' "${DESTINATION}"

installed_bundle_id="$(bundle_id "${DESTINATION}")"
if [[ "${DESTINATION}" == "${USER_APP}" && -d "${SYSTEM_APP}" ]]; then
  system_bundle_id="$(bundle_id "${SYSTEM_APP}")"
  if [[ -n "${system_bundle_id}" && "${system_bundle_id}" != "${installed_bundle_id}" ]]; then
    printf 'warning: found a different %s at %s (bundle id: %s).\n' "${APP_NAME}.app" "${SYSTEM_APP}" "${system_bundle_id}" >&2
    printf 'warning: this install updated %s. Open that path, or install system-wide with: make install-system\n' "${DESTINATION}" >&2
  fi
fi
