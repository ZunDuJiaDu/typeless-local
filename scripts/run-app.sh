#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WuZi"
USER_APP="${HOME}/Applications/${APP_NAME}.app"
SYSTEM_APP="/Applications/${APP_NAME}.app"
RUN_FROM_DIST="${RUN_FROM_DIST:-0}"

launch_app() {
  local app_path="$1"
  open "${app_path}"
  printf 'Launched %s\n' "${app_path}"
}

if [[ "${RUN_FROM_DIST}" == "1" ]]; then
  printf "warning: launching a freshly rebuilt dist/${APP_NAME}.app can reset macOS TCC / Accessibility expectations. Prefer an installed app for manual validation.\n" >&2
  APP_PATH="$(${ROOT_DIR}/scripts/build-app.sh)"
  launch_app "${APP_PATH}"
  exit 0
fi

for app_path in "${USER_APP}" "${SYSTEM_APP}"; do
  if [[ -d "${app_path}" ]]; then
    launch_app "${app_path}"
    exit 0
  fi
done

printf 'warning: no installed %s.app found in ~/Applications or /Applications.\n' "${APP_NAME}" >&2
printf "warning: launching a freshly rebuilt dist/${APP_NAME}.app can reset macOS TCC / Accessibility expectations. Run make install first for manual validation.\n" >&2
APP_PATH="$(${ROOT_DIR}/scripts/build-app.sh)"
launch_app "${APP_PATH}"
