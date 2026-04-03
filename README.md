# WuZi / 无字

WuZi / 无字 is a macOS 14+ menu-bar voice IME built with SwiftPM and AppKit.

## Current implementation
- LSUIElement app bundle packaging via `make build`
- Menu-bar status item with language switching and LLM refinement submenu
- Settings window with Base URL / API Key / Model, plus Test and Save
- Global Fn monitoring scaffold via session event tap
- Streaming speech recognition pipeline scaffold via Apple Speech
- Bottom HUD panel with RMS-driven waveform rendering and transcript/refining states
- Pasteboard + Cmd+V injection with ASCII fallback abstractions for CJK input sources
- OpenAI-compatible LLM refinement client with conservative prompt

## Commands
```bash
make test
make build
make run
make install                     # installs to ~/Applications by default
make install-system              # installs to /Applications
make install INSTALL_DIR="$HOME/Applications"
make clean
```

## Known limitations
- Fn suppression and cross-IME timing still require real-machine validation.
- Some target apps (secure fields, terminals, heavily sandboxed apps) may refuse synthetic paste.
- The first launch requires microphone, speech, and accessibility approval.


## Install location
- `make install` defaults to `~/Applications/WuZi.app`
- `make install-system` installs to `/Applications/WuZi.app`
- If both exist, macOS may open the wrong one if you launch the stale app manually.
