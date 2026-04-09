# Local AI Post-Processing with MLX Swift

## Overview

Add a local LLM option for AI text post-processing in yapyap. Users can download a Qwen3-4B model and run inference locally using MLX Swift, eliminating the need for an API key or internet connection for text correction. The existing online AI providers remain available — a separate toggle controls whether local or online is used.

## Model Catalog

| ID | Name | Size | Format | Source |
|----|------|------|--------|--------|
| `qwen3-4b` | Qwen3 4B Instruct | ~2.1 GB | MLX 4-bit | `mlx-community/Qwen3-4B-Instruct-4bit` on HuggingFace |

Only one model for now. More can be added later.

## Architecture

```
┌─ AI Tab (Settings) ────────────────────────┐
│  ☑ Enable AI text correction               │
│                                            │
│  ── Local Model ──────────────────────────  │
│  ☑ Use local model (overrides provider)    │
│  ┌─ Qwen3 4B ──── ~2.1 GB ─────────────┐  │
│  │  [● Active]              [Delete]    │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  ── Online Provider (dimmed when local) ── │
│  Provider: [OpenAI ▼]                      │
│  API Key:  [___________]                   │
│  Model:    [gpt-4o-mini ▼]                 │
└────────────────────────────────────────────┘
```

### New Files

- **`LLMModelManager.swift`** — LLM model catalog, download/delete, progress tracking. Stores models at `~/Library/Application Support/yapyap/llm-models/`. Follows the same download pattern as `ModelManager` (URLSession download delegate, progress, extraction).
- **`LocalLLMEngine.swift`** — MLX Swift wrapper. Loads model via MLXLLM, runs chat completion with the same system prompt + terms logic as the online path.

### Modified Files

- **`SettingsStore.swift`** — new setting: `useLocalAI: Bool`
- **`SettingsView.swift`** — add local model section to AI tab (toggle + model card with download/delete)
- **`AIProcessor.swift`** — route to `LocalLLMEngine` when `useLocalAI` is enabled and model is loaded
- **`project.yml`** — add MLX Swift and MLXLLM SPM dependencies

### Unchanged

ModelManager (ASR models), LocalASREngine, ASRClient, AudioEngine, TextProcessor, TextInjector, OverlayWindow, KeyMonitor

## LLM Model Management

### Storage Layout

```
~/Library/Application Support/yapyap/llm-models/
└── qwen3-4b/
    ├── config.json
    ├── model.safetensors
    ├── tokenizer.json
    ├── tokenizer_config.json
    └── ...
```

MLX models from HuggingFace are distributed as directories with multiple files (safetensors weights, tokenizer, config). MLXLLM can handle downloading from HuggingFace hub directly, or we download the files manually.

### LLMModelManager API

```swift
class LLMModelManager: ObservableObject {
    static let shared = LLMModelManager()

    @Published var downloadProgress: Double = 0     // 0.0...1.0
    @Published var downloadSpeed: String = ""        // "12.3 MB/s"
    @Published var isDownloading: Bool = false
    @Published var isDownloaded: Bool = false

    func download()
    func cancelDownload()
    func delete()
    func modelPath() -> URL?
}
```

Simpler than `ModelManager` since there's only one model. No catalog array or model selection needed.

## Local LLM Engine

### LocalLLMEngine API

```swift
class LocalLLMEngine {
    func loadModel(path: URL)
    func unloadModel()
    var isModelLoaded: Bool

    func generate(
        systemPrompt: String,
        userMessage: String,
        completion: @escaping (String) -> Void
    )
}
```

### MLX Swift Integration

- SPM dependencies: `mlx-swift`, `MLXLLM` (from `ml-explore/mlx-swift-examples`)
- Uses MLXLLM's model loading and generation APIs
- Model loaded into memory on first use, stays loaded while app runs
- Generation runs on a background thread, returns result on main thread
- Temperature: 0.3 (matching the online path)
- Max tokens: 4096 (matching the online path)

## AI Processor Routing

`AIProcessor.process()` is modified to check `useLocalAI`:

```
AIProcessor.process(text)
    │
    ├─ useLocalAI && model loaded?
    │   YES → LocalLLMEngine.generate(systemPrompt, text)
    │   NO  → existing HTTP API call (unchanged)
    │
    ▼
completion(correctedText)
```

The same system prompt construction logic (default prompt + terms list) applies to both paths.

## Settings & UI

### New Setting

| Property | Type | Key | Default |
|----------|------|-----|---------|
| `useLocalAI` | Bool | `"useLocalAI"` | `false` |

### AI Tab Changes

The AI tab is restructured:
1. Enable AI toggle (existing, unchanged)
2. **New**: "Local Model" section with toggle + model card (shown when AI is enabled)
3. Online provider section (existing, dimmed/disabled when local model toggle is on)

### Validation

- If `useLocalAI` is on but model not downloaded, fall back to online provider
- If both local and online are unavailable, AI processing is skipped (existing behavior)
