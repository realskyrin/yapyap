# Local AI Post-Processing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local LLM-based AI text post-processing using MLX Swift, allowing users to download and run Qwen3-4B locally instead of calling an online API.

**Architecture:** Two new files (`LLMModelManager.swift`, `LocalLLMEngine.swift`) plus modifications to settings, UI, AI processor routing, and project configuration. MLXLLM handles model downloading from HuggingFace and inference via its `ChatSession` API.

**Tech Stack:** Swift 5.10, MLX Swift LM (MLXLLM + MLXLMCommon), XcodeGen, macOS 14.0+

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `yapyap/Sources/LLMModelManager.swift` | Create | Wraps MLXLLM model loading, tracks download state, handles deletion |
| `yapyap/Sources/LocalLLMEngine.swift` | Create | ChatSession wrapper for text generation |
| `yapyap/Sources/SettingsStore.swift` | Modify | Add `useLocalAI` setting, L10n strings |
| `yapyap/Sources/SettingsView.swift` | Modify | Add local model section to AI tab |
| `yapyap/Sources/AIProcessor.swift` | Modify | Route to local or online based on setting |
| `yapyap/Sources/App.swift` | Modify | Update `useAI` check to include local AI |
| `project.yml` | Modify | Add mlx-swift-lm SPM dependency |

---

### Task 1: Add MLX Swift LM SPM Dependency

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Add SPM package and dependency to project.yml**

Add `packages` section and MLXLLM dependency:

```yaml
name: yapyap
options:
  bundleIdPrefix: cn.skyrin
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "16.0"
  minimumXcodeGenVersion: "2.30"

packages:
  mlx-swift-lm:
    url: https://github.com/ml-explore/mlx-swift-lm
    from: "2.29.1"

settings:
  base:
    SWIFT_VERSION: "5.10"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    ARCHS: arm64

targets:
  yapyap:
    type: application
    platform: macOS
    sources:
      - path: yapyap/Sources
      - path: yapyap/Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: cn.skyrin.yapyap
        INFOPLIST_FILE: yapyap/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: yapyap/Resources/yapyap.entitlements
        CODE_SIGN_IDENTITY: "-"
        PRODUCT_NAME: yapyap
        COMBINE_HIDPI_IMAGES: true
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        SWIFT_OBJC_BRIDGING_HEADER: yapyap/Sources/SherpaOnnx-Bridging-Header.h
        HEADER_SEARCH_PATHS: "$(PROJECT_DIR)/Frameworks/sherpa-onnx.xcframework/macos-arm64_x86_64/Headers"
        LIBRARY_SEARCH_PATHS: "$(PROJECT_DIR)/Frameworks"
        OTHER_LDFLAGS:
          - "-lc++"
          - "-lonnxruntime"
    entitlements:
      path: yapyap/Resources/yapyap.entitlements
    dependencies:
      - framework: Frameworks/sherpa-onnx.xcframework
      - package: mlx-swift-lm
        product: MLXLLM
```

Note: Read the current `project.yml` first and merge carefully — keep all existing settings (sherpa-onnx framework, bridging header, linker flags). Only add the `packages` section and the MLXLLM dependency.

- [ ] **Step 2: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

The first build will be slow as SPM resolves and compiles the MLX Swift dependencies. If the build fails due to SPM resolution issues, try:
```bash
cd /Users/yanlin/VSCodeProjects/yapyap && xcodegen && xcodebuild -resolvePackageDependencies -project yapyap.xcodeproj
```

Then retry the build. If there are version conflicts, adjust the `from:` version.

- [ ] **Step 3: Commit**

```bash
git add project.yml
git commit -m "feat: add mlx-swift-lm SPM dependency for local AI"
```

---

### Task 2: Add Settings and L10n Strings

**Files:**
- Modify: `yapyap/Sources/SettingsStore.swift`

- [ ] **Step 1: Add L10n strings for local AI**

Add to the `L10n` enum, after the existing AI-related strings (after `aiTermsTooltip`):

```swift
// Local AI
static var localAIHeader: String { lang == .zh ? "本地模型" : "Local Model" }
static var useLocalAI: String { lang == .zh ? "使用本地模型（覆盖在线服务）" : "Use local model (overrides provider)" }
static var localAIModelName: String { "Qwen3 4B Instruct" }
static var localAIModelSize: String { "~2.1 GB" }
static var localAIDownloading: String { lang == .zh ? "下载中..." : "Downloading..." }
static var localAIReady: String { lang == .zh ? "已就绪" : "Ready" }
static var localAINotDownloaded: String { lang == .zh ? "未下载" : "Not downloaded" }
static var localAILoading: String { lang == .zh ? "加载中..." : "Loading..." }
```

- [ ] **Step 2: Add useLocalAI setting property**

Add to `SettingsStore`, after the existing `aiTerms` property:

```swift
@Published var useLocalAI: Bool {
    didSet { UserDefaults.standard.set(useLocalAI, forKey: "useLocalAI") }
}
```

Add initialization in `init()`, after the `aiTerms` initialization:

```swift
self.useLocalAI = UserDefaults.standard.bool(forKey: "useLocalAI")
```

- [ ] **Step 3: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

- [ ] **Step 4: Commit**

```bash
git add yapyap/Sources/SettingsStore.swift
git commit -m "feat: add useLocalAI setting and L10n strings"
```

---

### Task 3: Create LLMModelManager

**Files:**
- Create: `yapyap/Sources/LLMModelManager.swift`

- [ ] **Step 1: Create LLMModelManager**

```swift
import Foundation
import MLXLLM
import MLXLMCommon
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "LLMModelManager")

class LLMModelManager: ObservableObject {
    static let shared = LLMModelManager()

    static let modelId = "mlx-community/Qwen3-4B-Instruct-4bit"

    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var isDownloaded: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private(set) var modelContainer: ModelContainer?

    private var loadTask: Task<Void, Never>?

    private init() {
        checkDownloadedState()
    }

    // MARK: - State

    private func checkDownloadedState() {
        // Check if the HuggingFace Hub cache has this model
        let cacheDir = hubCacheDirectory()
        isDownloaded = cacheDir != nil && modelContainer != nil
        // Also check if files exist in cache even if not loaded
        if !isDownloaded {
            isDownloaded = hubCacheDirectory() != nil
        }
    }

    private func hubCacheDirectory() -> URL? {
        // HuggingFace Hub stores models in ~/.cache/huggingface/hub/models--{org}--{name}
        let modelDirName = Self.modelId.replacingOccurrences(of: "/", with: "--")
        let cacheBase = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
            .appendingPathComponent("models--\(modelDirName)")
        return FileManager.default.fileExists(atPath: cacheBase.path) ? cacheBase : nil
    }

    // MARK: - Download & Load

    func downloadAndLoad() {
        guard !isDownloading, !isLoading else { return }

        loadTask = Task { @MainActor in
            isDownloading = true
            downloadProgress = 0
            error = nil

            do {
                let config = ModelConfiguration(id: Self.modelId)

                logger.info("Starting download/load: \(Self.modelId)")

                let container = try await LLMModelFactory.shared.loadContainer(
                    configuration: config
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress.fractionCompleted
                    }
                }

                self.modelContainer = container
                self.isDownloaded = true
                self.isDownloading = false
                self.downloadProgress = 1.0
                logger.info("Model loaded successfully")
            } catch {
                logger.error("Model load failed: \(error.localizedDescription)")
                self.error = error.localizedDescription
                self.isDownloading = false
            }
        }
    }

    func cancelDownload() {
        loadTask?.cancel()
        loadTask = nil
        isDownloading = false
        downloadProgress = 0
    }

    func delete() {
        modelContainer = nil

        if let cacheDir = hubCacheDirectory() {
            try? FileManager.default.removeItem(at: cacheDir)
            logger.info("Deleted LLM model cache")
        }

        isDownloaded = false
        error = nil
    }

    /// Load model into memory if already downloaded but not loaded
    func ensureLoaded() {
        guard isDownloaded, modelContainer == nil, !isLoading else { return }

        isLoading = true
        loadTask = Task { @MainActor in
            do {
                let config = ModelConfiguration(id: Self.modelId)
                let container = try await LLMModelFactory.shared.loadContainer(
                    configuration: config
                ) { _ in }

                self.modelContainer = container
                self.isLoading = false
                logger.info("Model loaded into memory")
            } catch {
                logger.error("Model load failed: \(error.localizedDescription)")
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

If imports fail, check that MLXLLM SPM dependency resolved correctly. You may need to verify the exact import names by looking at the resolved package.

- [ ] **Step 3: Commit**

```bash
git add yapyap/Sources/LLMModelManager.swift
git commit -m "feat: add LLMModelManager for local AI model download and lifecycle"
```

---

### Task 4: Create LocalLLMEngine

**Files:**
- Create: `yapyap/Sources/LocalLLMEngine.swift`

- [ ] **Step 1: Create LocalLLMEngine**

```swift
import Foundation
import MLXLMCommon
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "LocalLLMEngine")

enum LocalLLMEngine {
    /// Generate corrected text using the local LLM.
    /// Mirrors AIProcessor.process() interface — calls completion on main thread.
    static func process(
        text: String,
        completion: @escaping (String) -> Void
    ) {
        let settings = SettingsStore.shared
        guard let container = LLMModelManager.shared.modelContainer else {
            logger.error("Local LLM not loaded")
            completion(text)
            return
        }

        // Build system prompt (same logic as AIProcessor)
        var systemPrompt = settings.aiPrompt.isEmpty
            ? "You are a text correction assistant. Fix any speech recognition errors and grammar issues in the following text. Return only the corrected text, nothing else."
            : settings.aiPrompt

        if !settings.aiTerms.isEmpty {
            let termsList = settings.aiTerms.map { "- \($0)" }.joined(separator: "\n")
            systemPrompt += "\n\nIMPORTANT: The following terms/proper nouns must be used exactly as written when they appear in the text. Speech recognition may have misrecognized them:\n\(termsList)"
        }

        // Disable Qwen3 thinking mode for direct correction
        systemPrompt += "\n/no_think"

        logger.info("Local LLM processing: \(text.prefix(50))...")

        Task {
            do {
                let session = ChatSession(
                    container,
                    instructions: systemPrompt,
                    generateParameters: GenerateParameters(
                        maxTokens: 4096,
                        temperature: 0.3
                    )
                )

                let result = try await session.respond(to: text)
                let corrected = result.trimmingCharacters(in: .whitespacesAndNewlines)
                logger.info("Local LLM result: \(corrected.prefix(50))...")

                DispatchQueue.main.async { completion(corrected) }
            } catch {
                logger.error("Local LLM generation failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(text) }
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

- [ ] **Step 3: Commit**

```bash
git add yapyap/Sources/LocalLLMEngine.swift
git commit -m "feat: add LocalLLMEngine for local AI text correction via MLX"
```

---

### Task 5: Update AIProcessor and App.swift for Routing

**Files:**
- Modify: `yapyap/Sources/AIProcessor.swift`
- Modify: `yapyap/Sources/App.swift`

- [ ] **Step 1: Update AIProcessor.process() to route to local engine**

In `AIProcessor.swift`, replace the `process` method body. The routing logic: if `useLocalAI` is on and model is loaded, use `LocalLLMEngine`; otherwise fall through to existing online API call.

Add at the beginning of `process()`, before the existing `guard` statement:

```swift
// Route to local LLM if enabled and loaded
if settings.useLocalAI {
    if LLMModelManager.shared.modelContainer != nil {
        LocalLLMEngine.process(text: text, completion: completion)
        return
    } else {
        logger.warning("Local AI enabled but model not loaded, falling back to online")
    }
}
```

The full `process` method should read (add the routing block after the first `guard`):

```swift
static func process(
    text: String,
    completion: @escaping (String) -> Void
) {
    let settings = SettingsStore.shared
    guard settings.aiEnabled, !text.isEmpty else {
        logger.info("AI processing skipped (disabled)")
        completion(text)
        return
    }

    // Route to local LLM if enabled and loaded
    if settings.useLocalAI {
        if LLMModelManager.shared.modelContainer != nil {
            LocalLLMEngine.process(text: text, completion: completion)
            return
        } else {
            logger.warning("Local AI enabled but model not loaded, falling back to online")
        }
    }

    // Online path: require API key
    guard !settings.aiApiKey.isEmpty,
          !settings.aiBaseURL.isEmpty else {
        logger.info("AI processing skipped (not configured)")
        completion(text)
        return
    }

    // ... rest of existing online API code unchanged ...
```

- [ ] **Step 2: Update useAI check in App.swift**

In `App.swift`, find the `finalizeText()` method. Change the `useAI` check from:

```swift
let useAI = settings.aiEnabled && !settings.aiApiKey.isEmpty
```

to:

```swift
let useAI = settings.aiEnabled && (settings.useLocalAI || !settings.aiApiKey.isEmpty)
```

This ensures AI post-processing is triggered when using local model even without an API key.

- [ ] **Step 3: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

- [ ] **Step 4: Commit**

```bash
git add yapyap/Sources/AIProcessor.swift yapyap/Sources/App.swift
git commit -m "feat: route AI post-processing to local or online engine"
```

---

### Task 6: Update AI Tab UI with Local Model Section

**Files:**
- Modify: `yapyap/Sources/SettingsView.swift`

- [ ] **Step 1: Add local model section to AITabView**

In `AITabView`, add a local model section after the existing "Enable AI" toggle section and before the online provider section. The local model section appears when AI is enabled. When `useLocalAI` is on, the online provider section is dimmed.

Add `@ObservedObject private var llmManager = LLMModelManager.shared` to `AITabView`'s properties.

After the enable AI toggle `SectionCard`, insert:

```swift
if store.aiEnabled {
    // Local model section
    SectionCard(header: L10n.localAIHeader) {
        CardRow(label: L10n.useLocalAI) {
            Toggle("", isOn: $store.useLocalAI)
                .labelsHidden()
                .toggleStyle(.switch)
        }

        if store.useLocalAI {
            CardDivider()
            // Model card
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(L10n.localAIModelName)
                            .font(.system(size: 13, weight: .medium))
                        Text(L10n.localAIModelSize)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if llmManager.isDownloading {
                        Text(L10n.localAIDownloading)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if llmManager.isLoading {
                        Text(L10n.localAILoading)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if llmManager.isDownloaded {
                        Text(L10n.localAIReady)
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(L10n.localAINotDownloaded)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if llmManager.isDownloading {
                    Button(L10n.cancelDownload) {
                        llmManager.cancelDownload()
                    }
                    .controlSize(.small)
                } else if llmManager.isDownloaded {
                    Button(action: { llmManager.delete() }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button(L10n.modelDownload) {
                        llmManager.downloadAndLoad()
                    }
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Download progress
            if llmManager.isDownloading {
                VStack(spacing: 4) {
                    ProgressView(value: llmManager.downloadProgress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("\(Int(llmManager.downloadProgress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            // Error display
            if let error = llmManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }
}
```

- [ ] **Step 2: Dim online provider section when local AI is on**

Wrap the existing online provider `SectionCard` (the one with `L10n.aiHeader` containing provider picker, API key, model selector) with an opacity modifier:

Find the existing provider SectionCard block and add `.opacity(store.useLocalAI ? 0.5 : 1.0)` and `.disabled(store.useLocalAI)` to it.

For example, the existing block:
```swift
SectionCard(header: L10n.aiHeader) {
    // ... provider, API key, model fields ...
}
```
becomes:
```swift
SectionCard(header: L10n.aiHeader) {
    // ... provider, API key, model fields ...
}
.opacity(store.useLocalAI ? 0.5 : 1.0)
.disabled(store.useLocalAI)
```

Apply the same `.opacity` and `.disabled` modifiers to the prompt SectionCard and terms section that follow.

- [ ] **Step 3: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

Expected: AI tab shows the local model section when AI is enabled. Toggling "Use local model" shows the model card and dims the online provider section.

- [ ] **Step 4: Commit**

```bash
git add yapyap/Sources/SettingsView.swift
git commit -m "feat: add local AI model UI with download progress in AI tab"
```

---

### Task 7: Build Verification and Testing

**Files:** None (manual testing)

- [ ] **Step 1: Full build**

```bash
bash scripts/rebuild-and-open.sh
```

- [ ] **Step 2: Test online AI mode (existing)**

1. Open Settings → AI tab
2. Verify "Enable AI" toggle works
3. Verify provider/API key fields work as before
4. If configured, test recording with online AI correction

- [ ] **Step 3: Test local model download**

1. Enable AI → toggle "Use local model"
2. Click "Download" on Qwen3 4B card
3. Verify progress bar updates
4. Wait for download to complete (~2.1 GB)
5. Verify status shows "Ready"

- [ ] **Step 4: Test local AI correction**

1. With local model downloaded and "Use local model" enabled
2. Record speech with fn key
3. After recording stops, verify processing indicator shows
4. Verify corrected text is injected

- [ ] **Step 5: Test model deletion**

1. Click trash icon on model card
2. Verify model status changes to "Not downloaded"
3. Verify fallback to online provider works

- [ ] **Step 6: Commit any fixes**

```bash
git add -A
git commit -m "fix: integration fixes for local AI post-processing"
```
