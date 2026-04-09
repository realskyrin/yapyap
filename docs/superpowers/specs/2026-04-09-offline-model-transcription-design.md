# Offline Model Download & Local Transcription

## Overview

Add offline speech recognition to yapyap by integrating sherpa-onnx as a local ASR engine. Users can download Whisper and SenseVoice models, and use them for transcription without an internet connection. The existing Doubao WebSocket ASR remains available — users choose between online and local mode in Settings.

## Model Catalog

| ID | Name | Size | Languages | Engine |
|----|------|------|-----------|--------|
| `whisper-small` | Whisper Small | ~466 MB | 99 languages | sherpa-onnx offline |
| `whisper-medium` | Whisper Medium | ~1.5 GB | 99 languages | sherpa-onnx offline |
| `sensevoice-small` | SenseVoice Small | ~160 MB | zh/en/ja/ko/yue | sherpa-onnx offline |

Models are downloaded as `.tar.bz2` archives from sherpa-onnx GitHub releases, extracted to `~/Library/Application Support/yapyap/models/<model-id>/`.

## Architecture

```
┌─ Settings ─────────────────────────────┐
│  ASR Mode: [Online (Doubao)] / [Local] │
│  Local Model: [Whisper small ▼]        │
│  Model Library: [Download] [Delete]    │
└────────────────────────────────────────┘

┌─ Recording Flow ───────────────────────┐
│  AudioEngine (16kHz PCM, unchanged)    │
│         │                              │
│         ▼                              │
│  ┌─────────────────┐                   │
│  │ ASR Mode?       │                   │
│  │ Online → ASRClient (Doubao WS)     │
│  │ Local  → LocalASREngine (sherpa)   │
│  └─────────────────┘                   │
│         │                              │
│         ▼                              │
│  TextProcessor → TextInjector          │
└────────────────────────────────────────┘
```

### New Files

- **`ModelManager.swift`** — model catalog, download/extract/delete, progress tracking
- **`LocalASREngine.swift`** — sherpa-onnx wrapper, pseudo-streaming inference logic

### Modified Files

- **`SettingsStore.swift`** — new settings: `asrMode`, `selectedModelId`
- **`SettingsView.swift`** — model download UI in the Model tab
- **`App.swift`** — route audio to correct ASR backend based on mode
- **`project.yml`** — add sherpa-onnx SPM dependency

### Unchanged

AudioEngine, TextProcessor, TextInjector, OverlayWindow, KeyMonitor, SoundFeedback

## Model Management

### Storage Layout

```
~/Library/Application Support/yapyap/models/
├── whisper-small/
│   ├── encoder.onnx
│   ├── decoder.onnx
│   └── tokens.txt
├── whisper-medium/
│   └── ...
├── sensevoice-small/
│   └── ...
└── whisper-small.tar.bz2.partial    # in-progress download
```

### ModelManager API

```swift
class ModelManager: ObservableObject {
    @Published var models: [ModelInfo]                 // catalog + download state
    @Published var downloadProgress: [String: Double]  // modelId -> 0.0...1.0

    func download(_ modelId: String)
    func cancelDownload(_ modelId: String)
    func delete(_ modelId: String)
    func modelPath(_ modelId: String) -> URL?          // nil if not downloaded
}
```

### Download Flow

1. Download `.tar.bz2` archive via `URLSession` to a `.partial` file
2. Track progress via `URLSessionDownloadDelegate` (bytes received / total bytes)
3. On completion: extract archive to model directory, delete the archive
4. Support cancellation (cancel the URLSession download task)
5. No resume support in v1 — cancelled downloads restart from scratch

## Local Transcription Engine

### Pseudo-Streaming Approach

Whisper and SenseVoice are batch (offline) models — they don't support native streaming. To provide incremental text updates while the user speaks:

1. Audio accumulates in a PCM buffer as the user speaks
2. Every ~1.5 seconds, run inference on the **full accumulated buffer** on a background thread
3. Each pass produces updated text that replaces the previous result in the overlay
4. When recording stops, run one final inference pass for the definitive result
5. If a previous inference is still running when the timer fires, skip that cycle

### LocalASREngine API

```swift
class LocalASREngine {
    var onTextUpdate: ((String) -> Void)?

    func loadModel(_ modelInfo: ModelInfo, path: URL)  // load on app start or model switch
    func unloadModel()

    func start()                  // begin recording session
    func feedAudio(_ data: Data)  // called from AudioEngine's onAudioBuffer
    func stop()                   // final inference + cleanup
}
```

This mirrors the callback pattern of the existing `ASRClient` (`onTextUpdate`), so `App.swift` can swap between them with minimal changes.

### sherpa-onnx Integration

- Added as an SPM dependency in `project.yml`
- Uses the **Offline Recognizer** API for both Whisper and SenseVoice
- Model loaded into memory on first use, stays loaded while app is running (avoids reload cost per recording)
- Inference runs on a background `DispatchQueue` to avoid blocking audio capture

## Settings & UI

### New Settings

| Property | Type | Key | Default |
|----------|------|-----|---------|
| `asrMode` | Enum (`.online`, `.local`) | `"asrMode"` | `.online` |
| `selectedModelId` | String | `"selectedModelId"` | `""` |

### Model Tab Redesign

The existing "Model (ASR)" tab is restructured:

```
┌─ Model Tab ─────────────────────────────────┐
│                                             │
│  ASR Mode:  [● Online (Doubao)] [○ Local]   │
│                                             │
│  ── Online Settings (shown when Online) ──  │
│  App Key:      [___________]                │
│  Access Key:   [___________]                │
│  Resource ID:  [___________]                │
│  [Test Connection]                          │
│                                             │
│  ── Local Models (shown when Local) ──────  │
│                                             │
│  Active: Whisper Small                      │
│                                             │
│  ┌─ Whisper Small ──── 466 MB ───────────┐  │
│  │  99 languages  [● Active]             │  │
│  │  Downloaded              [Delete]     │  │
│  └───────────────────────────────────────┘  │
│  ┌─ Whisper Medium ─── 1.5 GB ──────────┐  │
│  │  99 languages                         │  │
│  │  ▓▓▓▓▓▓▓░░░ 65%  12.3 MB/s [Cancel]  │  │
│  └───────────────────────────────────────┘  │
│  ┌─ SenseVoice Small ── 160 MB ─────────┐  │
│  │  zh/en/ja/ko/yue     [Download]       │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

### Model Card States

- **Not downloaded:** shows size + Download button
- **Downloading:** shows progress bar (percentage + speed) + Cancel button
- **Downloaded:** shows Active toggle + Delete button
- **Active:** highlighted, used for local transcription

### Validation

If the user selects "Local" mode but no model is downloaded, show a hint prompting them to download one. Recording is disabled until a model is available.

## Integration with Existing Flow

The recording state machine in `App.swift` remains unchanged. The only difference is which ASR backend receives audio:

- **Online mode:** `ASRClient.connect()` → `sendAudio()` → `onTextUpdate` callback (existing flow)
- **Local mode:** `LocalASREngine.start()` → `feedAudio()` → `onTextUpdate` callback (new flow)

Both produce text updates via the same callback pattern, so `OverlayWindow.updateText()`, `TextProcessor`, and `TextInjector` work identically regardless of mode.

Audio format is already compatible — `AudioEngine` outputs 16kHz 16-bit mono PCM, which is what sherpa-onnx expects.
