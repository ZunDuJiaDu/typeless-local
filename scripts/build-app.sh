#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="WuZi"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"
BIN_DIR="$(cd "${ROOT_DIR}" && swift build -c "${CONFIGURATION}" --product "${APP_NAME}" >/dev/null && swift build -c "${CONFIGURATION}" --show-bin-path)"
BIN_PATH="${BIN_DIR}/${APP_NAME}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "${ROOT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
if [ -d "${ROOT_DIR}/Resources" ]; then
  rsync -a --exclude 'Info.plist' "${ROOT_DIR}/Resources/" "${APP_DIR}/Contents/Resources/"
fi
codesign --force --deep --sign "${CODESIGN_IDENTITY}" "${APP_DIR}" >/dev/null
printf '%s
' "${APP_DIR}"
