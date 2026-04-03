#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/Applications}"
APP_NAME="Typeless"
APP_PATH="$(${ROOT_DIR}/scripts/build-app.sh)"
DESTINATION="${INSTALL_DIR}/${APP_NAME}.app"

mkdir -p "${INSTALL_DIR}"
rm -rf "${DESTINATION}"
cp -R "${APP_PATH}" "${DESTINATION}"
printf '%s
' "${DESTINATION}"
