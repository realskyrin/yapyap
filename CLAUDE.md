# yapyap

macOS menu bar voice-to-text tool. SwiftUI + AppKit hybrid, uses XcodeGen for project generation.

## Build & Run

There are two build scripts:

- **`bash scripts/bundle.sh`** — Builds the app bundle only (`xcodegen` + `xcodebuild` + codesign). Use this to verify a compile after a code change. Fast, no launch.
- **`bash scripts/rebuild-and-open.sh`** — Builds, kills any running instance, launches the new build, and confirms it started. Slower because of the kill/launch cycle.

**Which to use when:**
- **Single, small, user-facing change** → `rebuild-and-open.sh` (fast feedback, see the result live)
- **Multi-step / multi-agent work (e.g. a superpowers plan executing many tasks)** → use `bundle.sh` between intermediate tasks to verify each one compiles, then use `rebuild-and-open.sh` only at stage milestones (end of a logical group of changes or before visual verification). Relaunching the app between every small task is wasteful.
- **Visual/behavioral verification** → after `rebuild-and-open.sh` succeeds, use a computer-use MCP (if available) to screenshot or interact with the running app.

## Project Structure

- `yapyap/Sources/` — All Swift source files
  - `App.swift` — Entry point (`@main`, `AppDelegate`)
  - `SettingsView.swift` — API config settings (SwiftUI)
  - `SettingsStore.swift` — Settings persistence, L10n strings
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

- Verify compiles with `bash scripts/bundle.sh`. Use `bash scripts/rebuild-and-open.sh` only at logical milestones (not after every small edit, especially during multi-agent plans).
- Bilingual UI (zh/en) — add new user-facing strings to the `L10n` enum in `SettingsStore.swift`.
- Minimum deployment target: macOS 14.0.
