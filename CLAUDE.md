# yapyap

macOS menu bar voice-to-text tool. SwiftUI + AppKit hybrid, uses XcodeGen for project generation.

## Build & Run

After every code change, run the rebuild script to build, restart, and verify the app:

```bash
bash scripts/rebuild-and-open.sh
```

This script builds the app bundle (via `bundle.sh` which runs `xcodegen` + `xcodebuild`), kills any running instance, launches the new build, and confirms it started.

## Project Structure

- `yapyap/Sources/` — All Swift source files
  - `App.swift` — Entry point (`@main`, `AppDelegate`)
  - `SettingsView.swift` — API config settings (SwiftUI)
  - `SettingsStore.swift` — Settings persistence, L10n strings
  - `StartupDialog.swift` — Startup permissions dialog (SwiftUI)
  - `KeyMonitor.swift` — fn key detection
  - `AudioEngine.swift` — Microphone capture
  - `ASRClient.swift` — WebSocket ASR client (Doubao)
  - `TextProcessor.swift` — Post-processing
  - `TextInjector.swift` — CGEvent keyboard simulation
  - `OverlayWindow.swift` — Recording indicator
- `yapyap/Resources/` — Info.plist, entitlements
- `scripts/` — Build and bundle scripts
- `project.yml` — XcodeGen project definition

## Key Rules

- **Always run `bash scripts/rebuild-and-open.sh` after modifying code** to verify the build and test changes live.
- Bilingual UI (zh/en) — add new user-facing strings to the `L10n` enum in `SettingsStore.swift`.
- Minimum deployment target: macOS 14.0.
