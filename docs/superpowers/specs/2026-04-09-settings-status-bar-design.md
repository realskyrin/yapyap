# Settings Status Bar — Design

## Overview

Add a persistent status bar at the bottom of the Settings window that
(a) shows the currently active voice (ASR) model and post-processing
model at a glance and (b) lets the user quick-switch between ready
models without navigating to the ASR or AI tab.

The status bar reflects `SettingsStore` in real time — any change made
from any tab (or from the popovers themselves) updates the labels live.

## Visual

```
┌──────────────────────── Settings (680 × 556) ────────────────────────┐
│ ┌──────────┐ ┌───────────────────────────────────────────────────┐  │
│ │ Sidebar  │ │ Tab content (ScrollView)                           │  │
│ │          │ │                                                    │  │
│ │ ...      │ │                                                    │  │
│ └──────────┘ └───────────────────────────────────────────────────┘  │
│ ─────────────────── Divider ───────────────────                      │
│  [● SenseVoice ⌄]  [✨ Qwen3 4B ⌄]                         v0.2.5    │
└──────────────────────────────────────────────────────────────────────┘
```

- Bar height: 36pt
- Window grows from 680×520 → 680×556 so existing tab content keeps
  its current height
- Left pills: voice-model pill, then post-processing pill, 8pt gap
- Right: version label `v{CFBundleShortVersionString}` in 11pt secondary

No "检查更新" (check updates) button is added — explicitly out of scope.

## Components

### `SettingsStatusBar` (new view)

Top-level container that observes:
- `SettingsStore.shared` — reads `asrMode`, `selectedModelId`,
  `aiEnabled`, `useLocalAI`, `aiProvider`, `aiModel`
- `ModelManager.shared` — reads `downloadedModels` to compute which
  local ASR models can appear in the quick-switch popover
- `LLMModelManager.shared` — reads `isDownloaded` to decide whether the
  local LLM row should appear

Layout: `HStack { voicePill; postProcessingPill; Spacer(); versionLabel }`
with 12pt horizontal padding and 8pt vertical padding.

The bar is included inside `SettingsView` for both normal and
`isStartup` modes.

### `StatusPill` (new reusable view)

Signature (conceptually):

```swift
struct StatusPill<Popover: View>: View {
    let indicator: IndicatorStyle     // .active (green dot) | .inactive (grey dot) | .icon(systemName:)
    let label: String
    @Binding var isOpen: Bool
    @ViewBuilder let popoverContent: () -> Popover
}
```

Renders `[● label ⌄]`:
- 6pt dot or SF Symbol (for post-processing when `aiEnabled` but using a
  non-green indicator is unnecessary — we stick with the green dot for
  "active" and grey for "off")
- 13pt label text
- `chevron.down` (or `chevron.up` when open)
- Subtle rounded-rectangle background (`controlBackgroundColor`), 6pt
  corner radius, hover fill via `.onHover`
- Tap toggles `isOpen`; SwiftUI `.popover(isPresented:)` anchors above

### `QuickSwitchRow` (new reusable view)

Signature:

```swift
struct QuickSwitchRow: View {
    let title: String
    let description: String
    let isActive: Bool
    let action: () -> Void
}
```

Renders one entry inside a popover:
- 13pt medium title (primary)
- 11pt secondary description, up to 2 lines
- Orange `checkmark` on the right when `isActive`
- Entire row is a plain-button; tap calls `action` and dismisses the
  popover (via the pill's `@State isOpen = false`)

Popovers use a fixed width (~280pt) and contain a vertical stack of
`QuickSwitchRow`s separated by 1pt dividers.

## Voice Model Pill

### Label text

```
asrMode == .online  →  "Doubao"   (豆包 in zh)
asrMode == .local   →  ModelManager.catalog.first { $0.id == store.selectedModelId }?.name ?? "Local"
```

Indicator dot: green when there is a working configuration
(`.online` with non-empty `appKey` and `accessKey`, OR `.local` with a
non-empty `selectedModelId`), grey otherwise.

### Popover entries

Always shown:

1. **Doubao 豆包**
   - Description: "在线识别，速度快，需配置 App Key" /
     "Cloud ASR, fast, requires App Key"
   - Active when `store.asrMode == .online`
   - Click: `store.asrMode = .online`

Then, for each `ModelInfo` in `ModelManager.shared.catalog` where
`ModelManager.shared.isDownloaded(model.id)`:

2. **{model.name}**
   - Description (new L10n, see Localization section below): a short
     one-liner per model, e.g. "非常快速。支持中文、英语、日语、韩语、粤语"
     for SenseVoice Small
   - Active when `store.asrMode == .local && store.selectedModelId == model.id`
   - Click: `store.asrMode = .local; store.selectedModelId = model.id`

Non-downloaded catalog entries are **hidden** from the popover. If the
user wants to add one they can still use the ASR tab.

## Post-Processing Pill

### Label text

```
!aiEnabled                     →  "未启用" / "Off"                 (grey dot)
aiEnabled && !useLocalAI       →  store.aiModel (e.g. "gpt-4o-mini")  (green dot)
aiEnabled && useLocalAI        →  "Qwen3 4B"                           (green dot)
```

(Truncated to 1 line with `.lineLimit(1)` in case of long online model
names.)

### Popover entries

Always shown:

1. **未启用 / Off**
   - Description: "不对识别结果做任何加工" / "Use raw transcription as-is"
   - Active when `!store.aiEnabled`
   - Click: `store.aiEnabled = false`

2. **在线 / Online**
   - Title: the active `store.aiProvider.displayName` (e.g. "OpenAI")
   - Description: the active `store.aiModel` (e.g. "gpt-4o-mini"), or a
     placeholder hint if the model/API key isn't configured
   - Active when `store.aiEnabled && !store.useLocalAI`
   - Click: `store.aiEnabled = true; store.useLocalAI = false`
   - Always shown (even if keys aren't filled in — the user is then
     nudged to configure in the AI tab)

Conditionally shown only if `LLMModelManager.shared.isDownloaded`:

3. **Qwen3 4B Instruct**
   - Description: "本地模型，离线运行" / "Local model, runs offline"
   - Active when `store.aiEnabled && store.useLocalAI`
   - Click:
     ```swift
     store.aiEnabled = true
     store.useLocalAI = true
     LLMModelManager.shared.ensureLoaded()
     ```

## Version Label

Right-aligned. Reads from `Bundle.main.infoDictionary["CFBundleShortVersionString"]`
at view-init time; prefixed with `v`. Font: 11pt, `secondary` color. No
button, no tooltip, no click target.

## Localization

New L10n entries (added to `SettingsStore.swift`):

| Key | zh | en |
|---|---|---|
| `statusBarVoiceOnlineName` | 豆包 | Doubao |
| `statusBarVoiceOnlineDesc` | 在线识别，速度快，需配置 App Key | Cloud ASR, fast, requires App Key |
| `statusBarPostOff` | 未启用 | Off |
| `statusBarPostOffDesc` | 不对识别结果做任何加工 | Use raw transcription as-is |
| `statusBarPostOnline` | 在线 | Online |
| `statusBarPostLocalName` | Qwen3 4B Instruct | Qwen3 4B Instruct |
| `statusBarPostLocalDesc` | 本地模型，离线运行 | Local model, runs offline |
| `statusBarModelSenseVoiceDesc` | 非常快速。支持中文、英语、日语、韩语、粤语 | Very fast. Supports Chinese, English, Japanese, Korean, Cantonese |
| `statusBarModelWhisperSmallDesc` | 99 种语言，速度较快 | 99 languages, fast |
| `statusBarModelWhisperMediumDesc` | 99 种语言，精度更高 | 99 languages, higher accuracy |

The per-model descriptions are keyed off `ModelInfo.id` via a small
helper function `localDescription(for modelId:)` on either `ModelInfo`
or a free function inside `SettingsView.swift`. Keeping it inside
`SettingsView.swift` avoids polluting `ModelManager.swift` with UI text.

## Reactivity

Because:
- `SettingsStore` publishes every field used by the bar via `@Published`
- `ModelManager.downloadedModels` is `@Published`
- `LLMModelManager.isDownloaded` is `@Published`

…observing all three with `@ObservedObject` causes the pill labels,
indicator colors, and popover row lists to refresh automatically when
the user downloads/deletes a model, toggles AI, changes provider, etc.

No manual NotificationCenter wiring is required.

## Window Height

`SettingsView.body` currently ends with `.frame(width: 680, height: 520)`.
It will become `.frame(width: 680, height: 556)` to accommodate the
36pt status bar without shrinking the existing scrolling content area.

The body structure changes from

```
HStack(spacing: 0) { Sidebar; Divider; ScrollView }.frame(...)
```

to

```
VStack(spacing: 0) {
    HStack(spacing: 0) { Sidebar; Divider; ScrollView }
        .frame(maxHeight: .infinity)
    Divider()
    SettingsStatusBar()
}.frame(width: 680, height: 556)
```

## Files Touched

- `yapyap/Sources/SettingsView.swift`
  - Wrap existing `HStack` inside a `VStack` and append
    `Divider() + SettingsStatusBar()`
  - Update `.frame(height:)` 520 → 556
  - Add `SettingsStatusBar`, `StatusPill`, `QuickSwitchRow` below the
    existing `SettingsView` struct (same file — these are internal UI
    helpers tightly coupled to settings)
- `yapyap/Sources/SettingsStore.swift`
  - Add the L10n keys listed above to the `L10n` enum
- No changes to `ModelManager.swift`, `LLMModelManager.swift`,
  `App.swift`, `Info.plist`, `project.yml`

## Out of Scope

- "检查更新 / Check Updates" button on the right side of the bar
- Showing non-downloaded local ASR models inside the voice popover
- Any kind of model download progress inside the bar
- Making the version label clickable (release notes, GitHub, etc.)
- Status bar on any other window (Overlay, startup dialog content)

## Success Criteria

1. Opening Settings shows the status bar at the bottom with the
   currently active voice model + post-processing model.
2. Switching asrMode or aiEnabled from the tabs updates the bar labels
   instantly without re-opening Settings.
3. Clicking the voice pill shows a popover listing `Doubao` + every
   downloaded local model; the current selection has an orange
   checkmark; clicking a row switches the active model and closes the
   popover.
4. Clicking the post-processing pill shows a popover with `Off`,
   `Online`, and (if downloaded) `Qwen3 4B Instruct`; clicking a row
   updates `aiEnabled` / `useLocalAI` and closes the popover.
5. Version label reads `v{CFBundleShortVersionString}` and no
   check-updates button is present.
6. Language toggle (zh/en) switches all status-bar text.
7. `bash scripts/rebuild-and-open.sh` builds cleanly and the app
   launches with the new bar visible.
