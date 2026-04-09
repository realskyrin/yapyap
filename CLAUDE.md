# yapyap

macOS menu bar voice-to-text tool. SwiftUI + AppKit hybrid, uses XcodeGen for project generation.

## Build & Run

There are three build scripts:

- **`bash scripts/compile-check.sh`** — Fastest. Runs `swift build -c debug` against Swift files changed since HEAD (including untracked) and surfaces only compilation errors. Exits 0 when clean or nothing to check, 1 on errors. Does NOT build an app bundle.
- **`bash scripts/bundle.sh`** — Builds the full app bundle (`xcodegen` + `xcodebuild` + codesign). Slower than `compile-check.sh` but produces a runnable `.app`. No launch.
- **`bash scripts/rebuild-and-open.sh`** — Builds, kills any running instance, launches the new build, and confirms it started. Slowest because of the kill/launch cycle.

**Which to use when:**
- **Intermediate edit during multi-step / multi-agent work** → `compile-check.sh` (fastest feedback that the code still compiles)
- **Verify a bundle builds end-to-end without launching** → `bundle.sh`
- **Single, small, user-facing change you want to see live** → `rebuild-and-open.sh`
- **Multi-step / multi-agent work (e.g. a superpowers plan executing many tasks)** → use `compile-check.sh` between intermediate tasks, `bundle.sh` when you need to confirm the full bundle builds, and `rebuild-and-open.sh` only at stage milestones (end of a logical group of changes or before visual verification). Relaunching the app between every small task is wasteful.
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

- Verify compiles with `bash scripts/compile-check.sh`. Use `bash scripts/rebuild-and-open.sh` only at logical milestones (not after every small edit, especially during multi-agent plans).
- Bilingual UI (zh/en) — add new user-facing strings to the `L10n` enum in `SettingsStore.swift`.
- Minimum deployment target: macOS 14.0.
