#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WuZi"

printf '== swift test ==\n'
(cd "${ROOT_DIR}" && swift test)

printf '\n== swift build ==\n'
(cd "${ROOT_DIR}" && swift build)

printf '\n== app bundle build ==\n'
APP_PATH="$("${ROOT_DIR}/scripts/build-app.sh")"
printf 'Built %s\n' "${APP_PATH}"

printf '\n== bundle structure ==\n'
test -d "${APP_PATH}/Contents/MacOS"
test -x "${APP_PATH}/Contents/MacOS/${APP_NAME}"
test -f "${APP_PATH}/Contents/Info.plist"
printf 'Verified %s bundle layout\n' "${APP_NAME}"

printf '\n== Info.plist checks ==\n'
PLIST="${APP_PATH}/Contents/Info.plist"
UI_ELEMENT="$("/usr/libexec/PlistBuddy" -c 'Print :LSUIElement' "${PLIST}")"
MIN_SYSTEM="$("/usr/libexec/PlistBuddy" -c 'Print :LSMinimumSystemVersion' "${PLIST}")"
BUNDLE_EXECUTABLE="$("/usr/libexec/PlistBuddy" -c 'Print :CFBundleExecutable' "${PLIST}")"
MIC_USAGE="$("/usr/libexec/PlistBuddy" -c 'Print :NSMicrophoneUsageDescription' "${PLIST}")"
SPEECH_USAGE="$("/usr/libexec/PlistBuddy" -c 'Print :NSSpeechRecognitionUsageDescription' "${PLIST}")"
[[ "${UI_ELEMENT}" == "true" ]]
[[ "${MIN_SYSTEM}" == "14.0" ]]
[[ "${BUNDLE_EXECUTABLE}" == "${APP_NAME}" ]]
[[ -n "${MIC_USAGE}" ]]
[[ -n "${SPEECH_USAGE}" ]]
printf 'LSUIElement=%s, LSMinimumSystemVersion=%s, CFBundleExecutable=%s\n' \
  "${UI_ELEMENT}" "${MIN_SYSTEM}" "${BUNDLE_EXECUTABLE}"

printf '\n== codesign verify ==\n'
codesign --verify --deep --strict "${APP_PATH}"
printf 'codesign verification passed\n'

printf '\n== installed app bundle note ==\n'
printf "Use an installed app bundle for manual TCC / Accessibility validation (for example %s or %s).\n" "${HOME}/Applications/${APP_NAME}.app" "/Applications/${APP_NAME}.app"
printf "A freshly rebuilt dist/${APP_NAME}.app is appropriate for packaging checks, but macOS may treat it as a new app identity.\n"
