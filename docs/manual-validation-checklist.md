# WuZi verification checklist

This checklist is for real-machine validation of the macOS menu-bar voice IME after `make verify` passes.

## Automated checks

Run the full automated bundle validation:

```bash
make verify
```

This currently verifies:
- `swift test`
- `swift build`
- `.app` bundle packaging via `scripts/build-app.sh`
- expected bundle structure (`Contents/MacOS/WuZi`, `Contents/Info.plist`)
- `Info.plist` packaging keys (`LSUIElement`, minimum macOS version, executable name, permission usage strings)
- `codesign --verify --deep --strict dist/WuZi.app`

## Manual validation matrix

### Permissions
- Launch the app with no permissions and confirm the menu-bar app remains available.
- Grant microphone access and verify audio capture starts.
- Grant speech recognition access and verify transcript updates appear.
- Grant Accessibility / Input Monitoring as required by the host system before testing Fn interception and paste injection.

### Input sources
- Validate one ASCII source (ABC or U.S.).
- Validate one CJK source (Simplified Chinese, Traditional Chinese, Japanese, or Korean).
- After each dictation session, verify the original input source is restored.

### Target apps
- TextEdit plain-text document
- Notes
- Safari or Chrome text area
- One code editor buffer
- One known limitation target (secure field or terminal) to confirm failure mode is graceful

### Interaction checklist
- Press and hold Fn: HUD appears quickly and stays bottom-center.
- Speak briefly, release Fn, and confirm a single paste attempt occurs.
- Run one longer dictation session and confirm waveform + transcript keep updating.
- Repeat two back-to-back sessions and confirm state resets cleanly.
- Test with LLM refinement disabled, then enabled, then misconfigured/timed out.
- Confirm prior clipboard contents are restored after injection.

## Troubleshooting

### Fn opens the emoji picker or dictation never starts
- Re-check Accessibility / Input Monitoring permissions for the built app.
- Inspect input-tap logs:

```bash
log stream --style compact --predicate 'subsystem == "WuZiApp" && category == "inputTap"'
```

### Speech starts but no transcript appears
- Re-check microphone and speech-recognition permissions.
- Inspect speech/audio logs:

```bash
log stream --style compact --predicate 'subsystem == "WuZiApp" && (category == "permissions" || category == "audio" || category == "speech")'
```

### Paste injection fails or restores the wrong input source
- Retry in a standard editable text view first (for example TextEdit).
- Secure fields, terminals, and some sandboxed targets are expected best-effort cases.
- Inspect injection logs:

```bash
log stream --style compact --predicate 'subsystem == "WuZiApp" && category == "injection"'
```

### Packaging/signing suspicion
- Re-run `make verify`.
- Confirm the built bundle is `dist/WuZi.app`.
- Inspect bundle metadata:

```bash
/usr/libexec/PlistBuddy -c 'Print' dist/WuZi.app/Contents/Info.plist
codesign --verify --deep --strict dist/WuZi.app
```
