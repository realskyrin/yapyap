# Settings Status Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent status bar at the bottom of the Settings window showing the currently active voice model + post-processing model, each with a quick-switch popover.

**Architecture:** A new `SettingsStatusBar` SwiftUI view is inserted below the existing sidebar/content `HStack` inside `SettingsView`. It observes `SettingsStore`, `ModelManager`, and `LLMModelManager` (all existing `ObservableObject`s) so the labels and popover contents update live. The pill component and popover row are reusable local types; no existing files move.

**Tech Stack:** SwiftUI, AppKit `NSPopover` (via SwiftUI `.popover(isPresented:arrowEdge:)`), XcodeGen + `bash scripts/rebuild-and-open.sh` for build & launch. **No test target exists** — verification is "build succeeds + app launches + visual check," matching the project's `CLAUDE.md` norm.

**Spec:** `docs/superpowers/specs/2026-04-09-settings-status-bar-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `yapyap/Sources/SettingsStore.swift` | Modify | Add 9 `L10n` static vars for status-bar strings |
| `yapyap/Sources/SettingsView.swift` | Modify | Wrap `SettingsView.body` in `VStack`, bump window height 520 → 556, append new `SettingsStatusBar`, `StatusPill`, `QuickSwitchRow` types at end of file |

No new files are created. All new types live inside `SettingsView.swift` because they are UI helpers tightly coupled to the Settings window and the existing 1313-line file is the natural home for other settings-specific views (`ASRTabView`, `ModelCardView`, `PromptPresetCard`, etc.).

---

## Task 1: Add L10n Strings

**Files:**
- Modify: `yapyap/Sources/SettingsStore.swift`

**Context:** The `L10n` enum (lines 15-161) holds every bilingual UI string in the app. We add a new `// Status bar` section with 9 entries used by pill labels and popover rows.

- [ ] **Step 1: Locate the insertion point**

Open `yapyap/Sources/SettingsStore.swift`. The `L10n` enum closes at line 161 with `}`. Insert the new block immediately before that closing `}`, right after the `launchApp` / `permissionGranted` / `permissionNotGranted` entries (around lines 158-160).

- [ ] **Step 2: Add the strings**

Insert this block right before the final `}` of the `L10n` enum (i.e. before line 161 in the current file):

```swift
    // Status bar
    static var statusBarVoiceOnlineName: String { lang == .zh ? "豆包" : "Doubao" }
    static var statusBarVoiceOnlineDesc: String {
        lang == .zh ? "在线识别，速度快，需配置 App Key" : "Cloud ASR, fast, requires App Key"
    }
    static var statusBarPostOff: String { lang == .zh ? "未启用" : "Off" }
    static var statusBarPostOffDesc: String {
        lang == .zh ? "不对识别结果做任何加工" : "Use raw transcription as-is"
    }
    static var statusBarPostOnline: String { lang == .zh ? "在线" : "Online" }
    static var statusBarPostLocalName: String { "Qwen3 4B Instruct" }
    static var statusBarPostLocalDesc: String {
        lang == .zh ? "本地模型，离线运行" : "Local model, runs offline"
    }
    static var statusBarModelSenseVoiceDesc: String {
        lang == .zh
            ? "非常快速。支持中文、英语、日语、韩语、粤语"
            : "Very fast. Supports Chinese, English, Japanese, Korean, Cantonese"
    }
    static var statusBarModelWhisperSmallDesc: String {
        lang == .zh ? "99 种语言，速度较快" : "99 languages, fast"
    }
    static var statusBarModelWhisperMediumDesc: String {
        lang == .zh ? "99 种语言，精度更高" : "99 languages, higher accuracy"
    }
```

- [ ] **Step 3: Verify the build**

Run: `bash scripts/rebuild-and-open.sh`

Expected output ends with: `==> ✅ yapyap is running (PID: ...)`.

The app itself looks unchanged — the strings aren't wired to any view yet. We're only verifying that the Swift file still compiles.

- [ ] **Step 4: Commit**

```bash
git add yapyap/Sources/SettingsStore.swift
git commit -m "feat: add L10n strings for settings status bar"
```

---

## Task 2: Add `StatusPill` and `QuickSwitchRow` Primitives

**Files:**
- Modify: `yapyap/Sources/SettingsView.swift` (append to end of file, after `UsageTabView`)

**Context:** These are the two reusable UI pieces used by `SettingsStatusBar`. `QuickSwitchRow` is a row inside a popover (bold title + secondary description + orange checkmark when active). `StatusPill` is a pill-shaped button (`● label ⌄`) that owns the `@State` for its popover open/closed state and renders arbitrary content inside.

`StatusPill` is **generic over its popover content type** so the voice and post-processing pills can supply different row layouts.

- [ ] **Step 1: Locate the insertion point**

Open `yapyap/Sources/SettingsView.swift`. Scroll to the bottom — the last type is `UsageTabView` (struct ending around line 1312 in the current file). Insert the new code **after** `UsageTabView`'s closing `}`, at the end of the file.

- [ ] **Step 2: Append `QuickSwitchRow`**

Add at the end of the file:

```swift
// MARK: - Status Bar: Quick Switch Row

struct QuickSwitchRow: View {
    let title: String
    let description: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Append `StatusPill`**

Add directly below `QuickSwitchRow`:

```swift
// MARK: - Status Bar: Pill

struct StatusPill<PopoverContent: View>: View {
    let label: String
    let isActive: Bool
    @ViewBuilder let popoverContent: (Binding<Bool>) -> PopoverContent

    @State private var isOpen = false
    @State private var isHovering = false

    var body: some View {
        Button(action: { isOpen.toggle() }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isActive ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(pillBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            popoverContent($isOpen)
        }
    }

    private var pillBackground: Color {
        if isOpen {
            return Color(nsColor: .controlBackgroundColor)
        }
        if isHovering {
            return Color(nsColor: .controlBackgroundColor).opacity(0.7)
        }
        return Color.clear
    }
}
```

- [ ] **Step 4: Verify the build**

Run: `bash scripts/rebuild-and-open.sh`

Expected: build succeeds, app launches. Still no visible change in Settings — the new types exist but aren't referenced anywhere.

If the build fails with "Generic parameter 'PopoverContent' could not be inferred," double-check that the closure on `.popover(isPresented:arrowEdge:content:)` is inside the `body` of `StatusPill` and that `@ViewBuilder let popoverContent:` is spelled correctly.

- [ ] **Step 5: Commit**

```bash
git add yapyap/Sources/SettingsView.swift
git commit -m "feat: add StatusPill and QuickSwitchRow primitives"
```

---

## Task 3: Add `SettingsStatusBar` Skeleton + Wire Into `SettingsView`

**Files:**
- Modify: `yapyap/Sources/SettingsView.swift`
  - Replace `SettingsView.body` (lines ~39-86) with a `VStack` that contains the existing `HStack` plus a `Divider()` and `SettingsStatusBar()`
  - Bump `.frame(width: 680, height: 520)` → `.frame(width: 680, height: 556)`
  - Append `SettingsStatusBar` type after `StatusPill` at end of file

**Context:** In this task we only render the **version label** on the right side of the bar — no pills yet. This gets the layout wiring (VStack, divider, window height, bar component) working in isolation so a visual diff is unambiguous.

- [ ] **Step 1: Replace `SettingsView.body`**

The current `SettingsView.body` (currently lines 39-86) is:

```swift
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    sidebarButton(tab)
                }
                Spacer()
                if isStartup {
                    Button(action: { onLaunch?() }) {
                        Text(L10n.launchApp)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 150)

            Divider()

            // Content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralTabView()
                    case .asr:
                        ASRTabView()
                    case .textProcessing:
                        TextProcessingTabView()
                    case .ai:
                        AITabView()
                    case .usage:
                        UsageTabView()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 520)
    }
```

Replace it with:

```swift
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        sidebarButton(tab)
                    }
                    Spacer()
                    if isStartup {
                        Button(action: { onLaunch?() }) {
                            Text(L10n.launchApp)
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .frame(width: 150)

                Divider()

                // Content
                ScrollView {
                    Group {
                        switch selectedTab {
                        case .general:
                            GeneralTabView()
                        case .asr:
                            ASRTabView()
                        case .textProcessing:
                            TextProcessingTabView()
                        case .ai:
                            AITabView()
                        case .usage:
                            UsageTabView()
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            Divider()

            SettingsStatusBar()
        }
        .frame(width: 680, height: 556)
    }
```

The changes are:
1. Wrap the existing `HStack(spacing: 0) { ... }` in `VStack(spacing: 0) { ... }`
2. Add `.frame(maxHeight: .infinity)` on the inner `HStack` so it fills the vertical space above the bar
3. After the `HStack`, add `Divider()` and `SettingsStatusBar()`
4. Change `.frame(width: 680, height: 520)` → `.frame(width: 680, height: 556)` on the outer `VStack`

- [ ] **Step 2: Append `SettingsStatusBar` (skeleton)**

Add at the very end of `yapyap/Sources/SettingsView.swift`, after the `StatusPill` struct from Task 2:

```swift
// MARK: - Settings Status Bar

struct SettingsStatusBar: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var llmManager = LLMModelManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            Text(versionString)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }

    // MARK: - Version

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "v\(version)"
    }
}
```

> The `@ObservedObject` lines for `modelManager` and `llmManager` look unused at this stage — they're here now because Tasks 4 and 5 will read from them. Swift does **not** emit unused-variable warnings for stored properties with property wrappers, so the build is clean.

- [ ] **Step 3: Verify the build and visual**

Run: `bash scripts/rebuild-and-open.sh`

Expected:
1. Build succeeds, app launches.
2. Open Settings from the menu bar (status bar icon → "设置…" / "Settings…").
3. At the bottom of the Settings window you see a thin horizontal divider followed by a short bar containing only `v1.0.0` (or whatever `CFBundleShortVersionString` currently resolves to — `Info.plist` currently reads `1.0.0`; release builds patch in the real tag) aligned to the right.
4. The window is slightly taller than before; the existing tab content is not clipped.

- [ ] **Step 4: Commit**

```bash
git add yapyap/Sources/SettingsView.swift
git commit -m "feat: scaffold settings status bar with version label"
```

---

## Task 4: Voice Model Pill

**Files:**
- Modify: `yapyap/Sources/SettingsView.swift` — extend `SettingsStatusBar`

**Context:** Add the voice pill to the left side of the bar. Label reflects `asrMode` + `selectedModelId`; the popover lists `Doubao` plus every downloaded local ASR model from `ModelManager.shared.catalog`, with the currently active row checkmarked.

- [ ] **Step 1: Replace `SettingsStatusBar.body`**

Find the `SettingsStatusBar` struct from Task 3. Replace its `body` with:

```swift
    var body: some View {
        HStack(spacing: 8) {
            voicePill
            Spacer()
            Text(versionString)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
```

- [ ] **Step 2: Add voice pill helpers**

Immediately after the `versionString` computed property inside `SettingsStatusBar`, add:

```swift
    // MARK: - Voice Pill

    private var voicePill: some View {
        StatusPill(
            label: voiceLabel,
            isActive: voiceActive
        ) { isOpen in
            VStack(spacing: 0) {
                QuickSwitchRow(
                    title: L10n.statusBarVoiceOnlineName,
                    description: L10n.statusBarVoiceOnlineDesc,
                    isActive: store.asrMode == .online
                ) {
                    store.asrMode = .online
                    isOpen.wrappedValue = false
                }
                ForEach(downloadedLocalModels, id: \.id) { model in
                    Divider()
                    QuickSwitchRow(
                        title: model.name,
                        description: localModelDescription(for: model.id),
                        isActive: store.asrMode == .local && store.selectedModelId == model.id
                    ) {
                        store.asrMode = .local
                        store.selectedModelId = model.id
                        isOpen.wrappedValue = false
                    }
                }
            }
            .frame(width: 280)
        }
    }

    private var voiceLabel: String {
        switch store.asrMode {
        case .online:
            return L10n.statusBarVoiceOnlineName
        case .local:
            return modelManager.catalog.first { $0.id == store.selectedModelId }?.name ?? "Local"
        }
    }

    private var voiceActive: Bool {
        switch store.asrMode {
        case .online:
            return !store.appKey.isEmpty && !store.accessKey.isEmpty
        case .local:
            return !store.selectedModelId.isEmpty
        }
    }

    private var downloadedLocalModels: [ModelInfo] {
        modelManager.catalog.filter { modelManager.downloadedModels.contains($0.id) }
    }

    private func localModelDescription(for modelId: String) -> String {
        switch modelId {
        case "sensevoice-small": return L10n.statusBarModelSenseVoiceDesc
        case "whisper-small": return L10n.statusBarModelWhisperSmallDesc
        case "whisper-medium": return L10n.statusBarModelWhisperMediumDesc
        default: return ""
        }
    }
```

- [ ] **Step 3: Verify the build and visuals**

Run: `bash scripts/rebuild-and-open.sh`

Expected — open Settings and check the status bar at the bottom:

1. **Pill visible:** `● Doubao ⌄` (if in online mode) or `● {localModelName} ⌄` (if in local mode) appears to the left of the version label.
2. **Indicator dot:** green if the current mode has a usable configuration (online with both `App Key` and `Access Key` filled, OR local with a `selectedModelId`), grey otherwise.
3. **Click the pill:** a popover appears above the pill with a row for `Doubao` plus one row per downloaded local model. The currently active row has an orange `✓` on the right.
4. **Click a different row:** the popover closes, the pill label updates to the new selection, and the ASR tab's controls reflect the switch (e.g., `asrMode` segmented control flips).
5. **Live reactivity:** open the ASR tab, download a new local model — once it finishes extracting, reopen the voice popover and the new model appears in the list without restarting the app. (If no local models are downloaded yet, the popover shows only the `Doubao` row — this is expected.)

If the popover opens *below* the pill instead of above, change `arrowEdge: .top` to `arrowEdge: .bottom` inside `StatusPill.body` — on macOS at the bottom of a window, SwiftUI usually auto-flips, but if not, `.bottom` forces below (which we don't want) while `.top` forces above. Keep `.top`; the auto-flip should place it above since there's no room below.

- [ ] **Step 4: Commit**

```bash
git add yapyap/Sources/SettingsView.swift
git commit -m "feat: add voice model pill with quick-switch popover"
```

---

## Task 5: Post-Processing Pill

**Files:**
- Modify: `yapyap/Sources/SettingsView.swift` — extend `SettingsStatusBar`

**Context:** Add the second pill to the left side of the bar, right after the voice pill. Label reflects `aiEnabled` / `useLocalAI` / `aiModel`; the popover lists `Off`, an `Online` row (showing the current provider + model), and (if `LLMModelManager.shared.isDownloaded`) a `Qwen3 4B Instruct` row.

- [ ] **Step 1: Add `postProcessingPill` to the HStack**

Update `SettingsStatusBar.body` to include the new pill between `voicePill` and `Spacer()`:

```swift
    var body: some View {
        HStack(spacing: 8) {
            voicePill
            postProcessingPill
            Spacer()
            Text(versionString)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
```

- [ ] **Step 2: Add post-processing pill helpers**

At the end of `SettingsStatusBar` (after `localModelDescription(for:)` from Task 4, but before the struct's closing `}`), add:

```swift
    // MARK: - Post-Processing Pill

    private var postProcessingPill: some View {
        StatusPill(
            label: postLabel,
            isActive: store.aiEnabled
        ) { isOpen in
            VStack(spacing: 0) {
                QuickSwitchRow(
                    title: L10n.statusBarPostOff,
                    description: L10n.statusBarPostOffDesc,
                    isActive: !store.aiEnabled
                ) {
                    store.aiEnabled = false
                    isOpen.wrappedValue = false
                }
                Divider()
                QuickSwitchRow(
                    title: store.aiProvider.displayName,
                    description: onlineRowDescription,
                    isActive: store.aiEnabled && !store.useLocalAI
                ) {
                    store.aiEnabled = true
                    store.useLocalAI = false
                    isOpen.wrappedValue = false
                }
                if llmManager.isDownloaded {
                    Divider()
                    QuickSwitchRow(
                        title: L10n.statusBarPostLocalName,
                        description: L10n.statusBarPostLocalDesc,
                        isActive: store.aiEnabled && store.useLocalAI
                    ) {
                        store.aiEnabled = true
                        store.useLocalAI = true
                        llmManager.ensureLoaded()
                        isOpen.wrappedValue = false
                    }
                }
            }
            .frame(width: 280)
        }
    }

    private var postLabel: String {
        if !store.aiEnabled { return L10n.statusBarPostOff }
        if store.useLocalAI { return "Qwen3 4B" }
        return store.aiModel.isEmpty ? L10n.statusBarPostOnline : store.aiModel
    }

    private var onlineRowDescription: String {
        if store.aiModel.isEmpty {
            return L10n.lang == .zh ? "请在后处理标签中配置" : "Configure in Post-Processing tab"
        }
        return store.aiModel
    }
```

- [ ] **Step 3: Verify the build and visuals**

Run: `bash scripts/rebuild-and-open.sh`

Expected:

1. **Two pills visible** on the left side of the status bar, separated by 8pt: e.g. `[● Doubao ⌄]  [● gpt-4o-mini ⌄]`.
2. **Post-processing pill label** reflects current state:
   - If AI is disabled: `● Off` / `● 未启用` with a grey dot.
   - If online AI is active: shows `store.aiModel` (or `Online` / `在线` if `aiModel` is blank) with a green dot.
   - If local AI is active: shows `Qwen3 4B` with a green dot.
3. **Click the post-processing pill:** popover shows `Off`, `{provider displayName}` (e.g. "OpenAI"), and — if you've already downloaded the local Qwen3 model in the Post-processing tab — `Qwen3 4B Instruct`. The currently active row has an orange checkmark.
4. **Click "Off"** in the popover → `aiEnabled` flips to false; pill label changes to `Off`. Reopen the popover — the `Off` row is now checkmarked.
5. **Click `{provider}` row** → `aiEnabled = true`, `useLocalAI = false`; pill label updates to the online model.
6. **Click `Qwen3 4B Instruct` row** (if present) → `aiEnabled = true`, `useLocalAI = true`, `llmManager.ensureLoaded()` runs; pill label changes to `Qwen3 4B`.
7. **Cross-tab reactivity:** open the Post-Processing (AI) tab and toggle the "Enable AI text correction" switch — the pill in the status bar updates instantly.

- [ ] **Step 4: Commit**

```bash
git add yapyap/Sources/SettingsView.swift
git commit -m "feat: add post-processing pill with quick-switch popover"
```

---

## Task 6: Final Verification

**Files:** None (verification only)

**Context:** Exercise the full feature end-to-end against the spec's success criteria. No code changes unless a bug surfaces.

- [ ] **Step 1: Fresh build and launch**

Run: `bash scripts/rebuild-and-open.sh`

Expected: clean build, app starts, no warnings about unused `modelManager`/`llmManager`.

- [ ] **Step 2: Walk through the spec's success criteria**

For each item, open Settings and verify:

1. **Bar visible at the bottom** showing voice pill + post-processing pill + version label. ✅
2. **Switching `asrMode` from the ASR tab** (segmented control Online/Local) updates the voice pill label instantly. ✅
3. **Clicking the voice pill** shows a popover listing `Doubao` + every downloaded local model; the current selection has an orange checkmark; clicking a row switches the active model and closes the popover. ✅
4. **Clicking the post-processing pill** shows a popover with `Off`, `Online`, and (if downloaded) `Qwen3 4B Instruct`; clicking updates `aiEnabled` / `useLocalAI` and closes the popover. ✅
5. **Version label** reads `v{CFBundleShortVersionString}` with no "检查更新" button. ✅
6. **Language toggle:** switch the General tab's language picker between 中文 and English. Both pill labels, popover titles, and popover descriptions all update in the new language immediately. ✅
7. **Rebuild script** completed with `✅ yapyap is running`. ✅

- [ ] **Step 3: Regression spot-checks**

- [ ] Startup dialog still works: temporarily launch via startup mode (skip if not easily reachable — just verify `isStartup` path in `SettingsView.body` hasn't broken by confirming the sidebar "Launch App" button still renders in the sidebar column, not under the bar).
- [ ] Sidebar "Launch App" button (visible when `isStartup == true`) is still positioned inside the sidebar column — the VStack wrap didn't move it.
- [ ] Scroll content area still scrolls: scroll the ASR tab's long content — the status bar stays pinned at the bottom and doesn't scroll with the content.
- [ ] Window is ~36pt taller than before; tab content height matches pre-change.

- [ ] **Step 4: Clean up any leftover warnings**

If `modelManager` or `llmManager` still show as unused, check that Tasks 4 and 5 both landed properly (they reference both via `downloadedLocalModels` and `llmManager.isDownloaded`). If something is missing, add it back.

Run: `bash scripts/rebuild-and-open.sh` once more to confirm a clean final build.

- [ ] **Step 5: No commit needed**

This task contains no source changes. If Step 4 required a fix, commit it with a message like:

```bash
git commit -m "fix: address settings status bar warnings"
```

Otherwise skip.

---

## Success Summary

When all tasks are complete, opening Settings will show:

- The usual sidebar + tab content, sitting above
- A 36pt status bar at the bottom with `[● VoiceModel ⌄]  [● PostProcModel ⌄]  ......  v0.2.5`
- Both pills open a popover above with selectable rows
- Everything reacts to settings changes made anywhere in the app
- No tests to run; verification is `bash scripts/rebuild-and-open.sh` + visual check, matching the project's existing pattern
