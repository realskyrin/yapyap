# Offline Model Download & Local Transcription Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add offline speech recognition to yapyap using sherpa-onnx, with model downloading, management, and pseudo-streaming transcription for Whisper and SenseVoice models.

**Architecture:** Two new files (`ModelManager.swift`, `LocalASREngine.swift`) plus modifications to settings, UI, and the recording flow in App.swift. sherpa-onnx is integrated via a pre-built static xcframework and its Swift API wrapper.

**Tech Stack:** Swift 5.10, sherpa-onnx v1.12.36 (pre-built xcframework), XcodeGen, macOS 14.0+

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `scripts/setup-sherpa-onnx.sh` | Create | Download and extract xcframework + Swift API wrapper |
| `yapyap/Sources/SherpaOnnx.swift` | Create | Swift API wrapper (copied from sherpa-onnx repo) |
| `yapyap/Sources/SherpaOnnx-Bridging-Header.h` | Create | C API bridging header for Swift |
| `yapyap/Sources/ModelManager.swift` | Create | Model catalog, download, extract, delete, state tracking |
| `yapyap/Sources/LocalASREngine.swift` | Create | sherpa-onnx offline recognizer, pseudo-streaming inference |
| `yapyap/Sources/SettingsStore.swift` | Modify | Add `ASRMode` enum, `asrMode`, `selectedModelId` settings, L10n strings |
| `yapyap/Sources/SettingsView.swift` | Modify | Redesign ASR tab with mode picker and model cards |
| `yapyap/Sources/App.swift` | Modify | Route audio to local or online ASR based on mode |
| `project.yml` | Modify | Add xcframework dependency, bridging header setting |

---

### Task 1: Setup sherpa-onnx Framework Integration

**Files:**
- Create: `scripts/setup-sherpa-onnx.sh`
- Create: `yapyap/Sources/SherpaOnnx-Bridging-Header.h`
- Modify: `project.yml`

- [ ] **Step 1: Create setup script to download xcframework**

```bash
#!/bin/bash
set -euo pipefail

VERSION="1.12.36"
FRAMEWORK_DIR="Frameworks"
ARCHIVE="sherpa-onnx-v${VERSION}-macos-xcframework-static.tar.bz2"
URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/v${VERSION}/${ARCHIVE}"

if [ -d "${FRAMEWORK_DIR}/sherpa_onnx.xcframework" ]; then
    echo "sherpa-onnx xcframework already exists, skipping download."
    exit 0
fi

mkdir -p "${FRAMEWORK_DIR}"
echo "Downloading sherpa-onnx v${VERSION} xcframework..."
curl -SL "${URL}" -o "${FRAMEWORK_DIR}/${ARCHIVE}"
echo "Extracting..."
cd "${FRAMEWORK_DIR}"
tar xjf "${ARCHIVE}"
rm "${ARCHIVE}"
echo "Done. xcframework at ${FRAMEWORK_DIR}/sherpa_onnx.xcframework"
```

Note: The exact xcframework directory name inside the archive may differ (e.g. `sherpa_onnx.xcframework` vs `sherpa-onnx.xcframework`). The implementer should download the archive, inspect its contents with `tar tjf`, and adjust the script and project.yml accordingly.

- [ ] **Step 2: Download the Swift API wrapper from the sherpa-onnx repo**

Download `SherpaOnnx.swift` from the sherpa-onnx repository and place it at `yapyap/Sources/SherpaOnnx.swift`:

```bash
curl -SL "https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/refs/heads/master/swift-api-examples/SherpaOnnx.swift" \
  -o yapyap/Sources/SherpaOnnx.swift
```

This file contains all the Swift wrapper classes and helper functions (`SherpaOnnxOfflineRecognizer`, `sherpaOnnxOfflineWhisperModelConfig`, etc.).

- [ ] **Step 3: Create bridging header**

Create `yapyap/Sources/SherpaOnnx-Bridging-Header.h`:

```c
#ifndef SherpaOnnx_Bridging_Header_h
#define SherpaOnnx_Bridging_Header_h

#import "sherpa-onnx/c-api/c-api.h"

#endif
```

- [ ] **Step 4: Update project.yml**

Add the xcframework dependency and bridging header to `project.yml`:

```yaml
name: yapyap
options:
  bundleIdPrefix: cn.skyrin
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "16.0"
  minimumXcodeGenVersion: "2.30"

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
    entitlements:
      path: yapyap/Resources/yapyap.entitlements
    dependencies:
      - framework: Frameworks/sherpa_onnx.xcframework
```

Note: The framework path and name must match the actual extracted xcframework directory. Verify after running the setup script.

- [ ] **Step 5: Run setup and verify build**

```bash
chmod +x scripts/setup-sherpa-onnx.sh
bash scripts/setup-sherpa-onnx.sh
bash scripts/rebuild-and-open.sh
```

Expected: App builds and launches. The xcframework links successfully. If there are linker errors, check the xcframework structure and adjust `project.yml` (may need `OTHER_LDFLAGS: ["-lc++"]` or additional framework dependencies like `Accelerate`).

- [ ] **Step 6: Add Frameworks/ to .gitignore**

```
# sherpa-onnx pre-built framework (downloaded by scripts/setup-sherpa-onnx.sh)
Frameworks/
```

- [ ] **Step 7: Commit**

```bash
git add scripts/setup-sherpa-onnx.sh yapyap/Sources/SherpaOnnx-Bridging-Header.h project.yml .gitignore
git add yapyap/Sources/SherpaOnnx.swift
git commit -m "feat: integrate sherpa-onnx xcframework for local ASR"
```

---

### Task 2: Add ASR Mode Settings and L10n Strings

**Files:**
- Modify: `yapyap/Sources/SettingsStore.swift`

- [ ] **Step 1: Add ASRMode enum and new L10n strings**

Add to `SettingsStore.swift`, after the `SoundTheme` enum:

```swift
enum ASRMode: String, CaseIterable {
    case online = "online"
    case local = "local"

    var displayName: String {
        switch self {
        case .online: return L10n.lang == .zh ? "在线 (豆包)" : "Online (Doubao)"
        case .local: return L10n.lang == .zh ? "本地模型" : "Local Model"
        }
    }
}
```

- [ ] **Step 2: Add new L10n strings**

Add these to the `L10n` enum:

```swift
// ASR mode
static var asrModeHeader: String { lang == .zh ? "识别模式" : "ASR Mode" }
static var localModelsHeader: String { lang == .zh ? "本地模型" : "Local Models" }
static var modelDownload: String { lang == .zh ? "下载" : "Download" }
static var modelDelete: String { lang == .zh ? "删除" : "Delete" }
static var modelActive: String { lang == .zh ? "使用中" : "Active" }
static var modelDownloading: String { lang == .zh ? "下载中..." : "Downloading..." }
static var modelExtracting: String { lang == .zh ? "解压中..." : "Extracting..." }
static var modelNotDownloaded: String { lang == .zh ? "未下载" : "Not downloaded" }
static var modelDownloaded: String { lang == .zh ? "已下载" : "Downloaded" }
static var noModelHint: String {
    lang == .zh
        ? "请先下载一个模型以使用本地识别"
        : "Please download a model to use local recognition"
}
static var notConfiguredLocalTitle: String { lang == .zh ? "模型未就绪" : "Model Not Ready" }
static var notConfiguredLocalMessage: String {
    lang == .zh
        ? "请在设置中下载并选择一个本地模型。"
        : "Please download and select a local model in Settings."
}
static var cancelDownload: String { lang == .zh ? "取消" : "Cancel" }
static var languages99: String { lang == .zh ? "99 种语言" : "99 languages" }
static var languagesCJKE: String { lang == .zh ? "中/英/日/韩/粤" : "zh/en/ja/ko/yue" }
```

- [ ] **Step 3: Add settings properties to SettingsStore**

Add these published properties to `SettingsStore`:

```swift
@Published var asrMode: ASRMode {
    didSet { UserDefaults.standard.set(asrMode.rawValue, forKey: "asrMode") }
}
@Published var selectedModelId: String {
    didSet { UserDefaults.standard.set(selectedModelId, forKey: "selectedModelId") }
}
```

Add initialization in `init()`, after the `soundTheme` init:

```swift
self.asrMode = ASRMode(rawValue: UserDefaults.standard.string(forKey: "asrMode") ?? "") ?? .online
self.selectedModelId = UserDefaults.standard.string(forKey: "selectedModelId") ?? ""
```

- [ ] **Step 4: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

Expected: Builds successfully. No visible changes yet.

- [ ] **Step 5: Commit**

```bash
git add yapyap/Sources/SettingsStore.swift
git commit -m "feat: add ASR mode settings and L10n strings for local model support"
```

---

### Task 3: Create ModelManager

**Files:**
- Create: `yapyap/Sources/ModelManager.swift`

- [ ] **Step 1: Create ModelManager with model catalog**

Create `yapyap/Sources/ModelManager.swift`:

```swift
import Foundation
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "ModelManager")

enum ModelEngineType {
    case whisper
    case senseVoice
}

struct ModelInfo: Identifiable {
    let id: String
    let name: String
    let engineType: ModelEngineType
    let downloadURL: String
    let extractedDirName: String
    let sizeDescription: String
    let languagesDescription: String
    // Model-specific file paths (relative to extracted directory)
    let whisperEncoder: String?
    let whisperDecoder: String?
    let senseVoiceModel: String?
    let tokensFile: String

    var isWhisper: Bool { engineType == .whisper }
}

class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published var downloadProgress: [String: Double] = [:]   // modelId -> 0.0...1.0
    @Published var downloadSpeed: [String: String] = [:]      // modelId -> "12.3 MB/s"
    @Published var isExtracting: [String: Bool] = [:]          // modelId -> true during extraction
    @Published var downloadedModels: Set<String> = []          // set of downloaded model IDs

    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var downloadDelegates: [String: DownloadDelegate] = [:]

    let catalog: [ModelInfo] = [
        ModelInfo(
            id: "whisper-small",
            name: "Whisper Small",
            engineType: .whisper,
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-small.tar.bz2",
            extractedDirName: "sherpa-onnx-whisper-small",
            sizeDescription: "~466 MB",
            languagesDescription: L10n.languages99,
            whisperEncoder: "small-encoder.int8.onnx",
            whisperDecoder: "small-decoder.int8.onnx",
            senseVoiceModel: nil,
            tokensFile: "small-tokens.txt"
        ),
        ModelInfo(
            id: "whisper-medium",
            name: "Whisper Medium",
            engineType: .whisper,
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-medium.tar.bz2",
            extractedDirName: "sherpa-onnx-whisper-medium",
            sizeDescription: "~1.5 GB",
            languagesDescription: L10n.languages99,
            whisperEncoder: "medium-encoder.int8.onnx",
            whisperDecoder: "medium-decoder.int8.onnx",
            senseVoiceModel: nil,
            tokensFile: "medium-tokens.txt"
        ),
        ModelInfo(
            id: "sensevoice-small",
            name: "SenseVoice Small",
            engineType: .senseVoice,
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2",
            extractedDirName: "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17",
            sizeDescription: "~160 MB",
            languagesDescription: L10n.languagesCJKE,
            whisperEncoder: nil,
            whisperDecoder: nil,
            senseVoiceModel: "model.int8.onnx",
            tokensFile: "tokens.txt"
        ),
    ]

    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("yapyap/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        refreshDownloadedState()
    }

    // MARK: - State

    func refreshDownloadedState() {
        var downloaded = Set<String>()
        for model in catalog {
            let dir = modelsDirectory.appendingPathComponent(model.extractedDirName)
            if FileManager.default.fileExists(atPath: dir.path) {
                downloaded.insert(model.id)
            }
        }
        DispatchQueue.main.async {
            self.downloadedModels = downloaded
        }
    }

    func isDownloaded(_ modelId: String) -> Bool {
        downloadedModels.contains(modelId)
    }

    func isDownloading(_ modelId: String) -> Bool {
        downloadTasks[modelId] != nil
    }

    func modelPath(for model: ModelInfo) -> URL? {
        let dir = modelsDirectory.appendingPathComponent(model.extractedDirName)
        guard FileManager.default.fileExists(atPath: dir.path) else { return nil }
        return dir
    }

    func model(for id: String) -> ModelInfo? {
        catalog.first { $0.id == id }
    }

    // MARK: - Download

    func download(_ modelId: String) {
        guard let model = model(for: modelId),
              !isDownloading(modelId),
              !isDownloaded(modelId) else { return }

        guard let url = URL(string: model.downloadURL) else {
            logger.error("Invalid download URL for \(modelId)")
            return
        }

        logger.info("Starting download: \(model.name)")

        let delegate = DownloadDelegate(
            modelId: modelId,
            manager: self
        )
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: url)

        downloadDelegates[modelId] = delegate
        downloadTasks[modelId] = task

        DispatchQueue.main.async {
            self.downloadProgress[modelId] = 0
            self.downloadSpeed[modelId] = ""
        }

        task.resume()
    }

    func cancelDownload(_ modelId: String) {
        guard let task = downloadTasks[modelId] else { return }
        logger.info("Cancelling download: \(modelId)")
        task.cancel()
        cleanupDownload(modelId)
    }

    func delete(_ modelId: String) {
        guard let model = model(for: modelId) else { return }
        let dir = modelsDirectory.appendingPathComponent(model.extractedDirName)
        try? FileManager.default.removeItem(at: dir)
        logger.info("Deleted model: \(model.name)")

        // If this was the selected model, clear selection
        if SettingsStore.shared.selectedModelId == modelId {
            SettingsStore.shared.selectedModelId = ""
        }

        refreshDownloadedState()
    }

    // MARK: - Internal

    fileprivate func handleDownloadComplete(_ modelId: String, location: URL) {
        guard let model = model(for: modelId) else {
            cleanupDownload(modelId)
            return
        }

        DispatchQueue.main.async {
            self.isExtracting[modelId] = true
        }

        let destination = modelsDirectory

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            logger.info("Extracting \(model.name) to \(destination.path)")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["xjf", location.path, "-C", destination.path]

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    logger.info("Extraction complete: \(model.name)")
                    self.refreshDownloadedState()

                    // Auto-select if no model is currently selected
                    DispatchQueue.main.async {
                        if SettingsStore.shared.selectedModelId.isEmpty {
                            SettingsStore.shared.selectedModelId = modelId
                        }
                    }
                } else {
                    logger.error("Extraction failed with status \(process.terminationStatus)")
                }
            } catch {
                logger.error("Extraction error: \(error.localizedDescription)")
            }

            DispatchQueue.main.async {
                self.isExtracting[modelId] = false
            }
            self.cleanupDownload(modelId)
        }
    }

    fileprivate func handleDownloadError(_ modelId: String, error: Error) {
        logger.error("Download failed for \(modelId): \(error.localizedDescription)")
        cleanupDownload(modelId)
    }

    private func cleanupDownload(_ modelId: String) {
        downloadTasks[modelId] = nil
        downloadDelegates[modelId] = nil
        DispatchQueue.main.async {
            self.downloadProgress.removeValue(forKey: modelId)
            self.downloadSpeed.removeValue(forKey: modelId)
        }
    }
}

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let modelId: String
    weak var manager: ModelManager?
    private var lastProgressTime: Date = .distantPast
    private var lastBytes: Int64 = 0
    private var lastSpeedUpdate: Date = .distantPast

    init(modelId: String, manager: ModelManager) {
        self.modelId = modelId
        self.manager = manager
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let now = Date()

        // Throttle progress updates to max 10/sec
        guard now.timeIntervalSince(lastProgressTime) >= 0.1 else { return }
        lastProgressTime = now

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

        // Calculate speed every 0.5s
        var speedStr = ""
        let elapsed = now.timeIntervalSince(lastSpeedUpdate)
        if elapsed >= 0.5 {
            let bytesInInterval = totalBytesWritten - lastBytes
            let speed = Double(bytesInInterval) / elapsed
            let mbps = speed / (1024 * 1024)
            speedStr = String(format: "%.1f MB/s", mbps)
            lastBytes = totalBytesWritten
            lastSpeedUpdate = now
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, let manager = self.manager else { return }
            manager.downloadProgress[self.modelId] = progress
            if !speedStr.isEmpty {
                manager.downloadSpeed[self.modelId] = speedStr
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Copy to a temp location before URLSession deletes it
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".tar.bz2")
        try? FileManager.default.copyItem(at: location, to: tempURL)
        manager?.handleDownloadComplete(modelId, location: tempURL)
        // Clean up temp file after extraction completes (handled by the extraction process)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error, (error as NSError).code != NSURLErrorCancelled {
            manager?.handleDownloadError(modelId, error: error)
        }
    }
}
```

**Important note on model file names:** The catalog hardcodes file names like `small-encoder.int8.onnx`. These must be verified by downloading a model archive and checking contents (`tar tjf <archive>.tar.bz2 | head -20`). If the actual file names differ (e.g., `small-encoder.onnx` without int8), update the catalog entries accordingly.

- [ ] **Step 2: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

Expected: Builds successfully.

- [ ] **Step 3: Commit**

```bash
git add yapyap/Sources/ModelManager.swift
git commit -m "feat: add ModelManager with model catalog, download, and extraction"
```

---

### Task 4: Create LocalASREngine

**Files:**
- Create: `yapyap/Sources/LocalASREngine.swift`

- [ ] **Step 1: Create LocalASREngine with pseudo-streaming**

Create `yapyap/Sources/LocalASREngine.swift`:

```swift
import Foundation
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "LocalASREngine")

class LocalASREngine {
    var onTextUpdate: ((String) -> Void)?

    private var recognizer: SherpaOnnxOfflineRecognizer?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private var inferenceTimer: DispatchSourceTimer?
    private var isInferenceRunning = false
    private var isSessionActive = false
    private let inferenceQueue = DispatchQueue(label: "cn.skyrin.yapyap.localASR", qos: .userInitiated)
    private let inferenceInterval: TimeInterval = 1.5

    // MARK: - Model Loading

    func loadModel(_ model: ModelInfo, path: URL) {
        unloadModel()

        logger.info("Loading model: \(model.name) from \(path.path)")

        var modelConfig: SherpaOnnxOfflineModelConfig

        if model.isWhisper {
            guard let encoder = model.whisperEncoder,
                  let decoder = model.whisperDecoder else {
                logger.error("Whisper model missing encoder/decoder config")
                return
            }

            let whisperConfig = sherpaOnnxOfflineWhisperModelConfig(
                encoder: path.appendingPathComponent(encoder).path,
                decoder: path.appendingPathComponent(decoder).path
            )

            modelConfig = sherpaOnnxOfflineModelConfig(
                tokens: path.appendingPathComponent(model.tokensFile).path,
                whisper: whisperConfig,
                numThreads: 4,
                modelType: "whisper"
            )
        } else {
            guard let senseModel = model.senseVoiceModel else {
                logger.error("SenseVoice model missing model config")
                return
            }

            let senseVoiceConfig = sherpaOnnxOfflineSenseVoiceModelConfig(
                model: path.appendingPathComponent(senseModel).path,
                useInverseTextNormalization: true
            )

            modelConfig = sherpaOnnxOfflineModelConfig(
                tokens: path.appendingPathComponent(model.tokensFile).path,
                numThreads: 4,
                senseVoice: senseVoiceConfig
            )
        }

        let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)
        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig
        )

        recognizer = SherpaOnnxOfflineRecognizer(config: &config)

        if recognizer != nil {
            logger.info("Model loaded successfully: \(model.name)")
        } else {
            logger.error("Failed to create recognizer for \(model.name)")
        }
    }

    func unloadModel() {
        stop()
        recognizer = nil
        logger.info("Model unloaded")
    }

    var isModelLoaded: Bool {
        recognizer != nil
    }

    // MARK: - Session

    func start() {
        guard recognizer != nil else {
            logger.error("Cannot start: no model loaded")
            return
        }

        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()
        isSessionActive = true

        // Start periodic inference timer
        let timer = DispatchSource.makeTimerSource(queue: inferenceQueue)
        timer.schedule(deadline: .now() + inferenceInterval, repeating: inferenceInterval)
        timer.setEventHandler { [weak self] in
            self?.runInference()
        }
        timer.resume()
        inferenceTimer = timer

        logger.info("Recording session started")
    }

    func feedAudio(_ data: Data) {
        // Convert Int16 PCM data to Float samples normalized to [-1, 1]
        let int16Count = data.count / MemoryLayout<Int16>.size
        let samples: [Float] = data.withUnsafeBytes { raw in
            let int16Ptr = raw.bindMemory(to: Int16.self)
            return (0..<int16Count).map { Float(int16Ptr[$0]) / 32768.0 }
        }

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()
    }

    func stop() {
        guard isSessionActive else { return }
        isSessionActive = false

        inferenceTimer?.cancel()
        inferenceTimer = nil

        // Run final inference with complete audio
        inferenceQueue.async { [weak self] in
            self?.runInference()
        }

        logger.info("Recording session stopped")
    }

    // MARK: - Inference

    private func runInference() {
        guard let recognizer, !isInferenceRunning else { return }

        bufferLock.lock()
        let samples = audioBuffer
        bufferLock.unlock()

        guard !samples.isEmpty else { return }

        isInferenceRunning = true

        let result = recognizer.decode(samples: samples, sampleRate: 16_000)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

        logger.debug("Inference result (\(samples.count) samples): \(text.prefix(100))")

        if !text.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onTextUpdate?(text)
            }
        }

        isInferenceRunning = false
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

Expected: Builds successfully.

- [ ] **Step 3: Commit**

```bash
git add yapyap/Sources/LocalASREngine.swift
git commit -m "feat: add LocalASREngine with sherpa-onnx pseudo-streaming transcription"
```

---

### Task 5: Update App.swift for Mode Routing

**Files:**
- Modify: `yapyap/Sources/App.swift`

- [ ] **Step 1: Add localASREngine and modelManager properties**

In `AppDelegate`, add new properties alongside existing ones:

```swift
private var localASREngine: LocalASREngine!
private var modelManager: ModelManager!
```

- [ ] **Step 2: Initialize in setupComponents()**

Add to `setupComponents()` after the existing component initialization:

```swift
localASREngine = LocalASREngine()
modelManager = ModelManager.shared
```

- [ ] **Step 3: Update startRecording() for mode routing**

Replace `startRecording()` with:

```swift
private func startRecording() {
    let settings = SettingsStore.shared

    if settings.asrMode == .online {
        guard !settings.appKey.isEmpty, !settings.accessKey.isEmpty else {
            showNotConfiguredAlert()
            return
        }
    } else {
        guard let model = modelManager.model(for: settings.selectedModelId),
              let modelPath = modelManager.modelPath(for: model) else {
            showNotConfiguredLocalAlert()
            return
        }
        // Load model if not already loaded
        if !localASREngine.isModelLoaded {
            localASREngine.loadModel(model, path: modelPath)
        }
        guard localASREngine.isModelLoaded else {
            showNotConfiguredLocalAlert()
            return
        }
    }

    if !TextInjector.checkAccessibility() {
        return
    }

    TextInjector.reset()
    latestRawText = ""
    latestProcessedText = ""

    SoundFeedback.shared.playStart()

    DispatchQueue.main.async {
        if let button = self.statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
        }
        self.overlayWindow.show()
    }

    let textHandler: (String) -> Void = { [weak self] text in
        self?.latestRawText = text
        let processed = TextProcessor.process(text)
        self?.latestProcessedText = processed
        self?.overlayWindow.updateText(processed)
    }

    if settings.asrMode == .online {
        asrClient.onTextUpdate = textHandler
        asrClient.connect()

        audioEngine.onAudioBuffer = { [weak self] data in
            self?.asrClient.sendAudio(data: data)
        }
    } else {
        localASREngine.onTextUpdate = textHandler
        localASREngine.start()

        audioEngine.onAudioBuffer = { [weak self] data in
            self?.localASREngine.feedAudio(data)
        }
    }

    audioEngine.onAudioLevel = { [weak self] level in
        DispatchQueue.main.async {
            self?.overlayWindow.updateLevel(level)
        }
    }
    audioEngine.start()
}
```

- [ ] **Step 4: Update stopRecording() for mode routing**

Replace `stopRecording()` with:

```swift
private func stopRecording() {
    SoundFeedback.shared.playStop()

    DispatchQueue.main.async {
        if let button = self.statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "yapyap")
        }
    }

    let settings = SettingsStore.shared

    // Delay 0.5s before stopping audio to capture trailing speech
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self else { return }
        self.audioEngine.stop()

        if settings.asrMode == .online {
            self.asrClient.sendLastAudio()

            // Give the server time to process the final audio before disconnecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.asrClient.disconnect()
                self.finalizeText()
            }
        } else {
            self.localASREngine.stop()

            // Give local engine time for final inference
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                self.finalizeText()
            }
        }
    }
}
```

- [ ] **Step 5: Extract finalizeText() helper**

Add a new method to `AppDelegate`:

```swift
private func finalizeText() {
    let settings = SettingsStore.shared
    let useAI = settings.aiEnabled && !settings.aiApiKey.isEmpty

    let textToInject = useAI ? self.latestRawText : self.latestProcessedText
    guard !textToInject.isEmpty else {
        self.overlayWindow.hide()
        self.recordingMode = .idle
        return
    }

    if useAI {
        self.overlayWindow.showProcessing()
        AIProcessor.process(text: textToInject) { [weak self] corrected in
            guard let self else { return }
            let finalText = TextProcessor.process(corrected)
            self.overlayWindow.updateText(finalText)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                TextInjector.update(fullText: finalText)
                self.overlayWindow.hide()
                self.recordingMode = .idle
            }
        }
    } else {
        TextInjector.update(fullText: textToInject)
        self.overlayWindow.hide()
        self.recordingMode = .idle
    }
}
```

- [ ] **Step 6: Update cancelRecording() for mode routing**

Replace `cancelRecording()` with:

```swift
private func cancelRecording() {
    audioEngine.stop()
    if SettingsStore.shared.asrMode == .online {
        asrClient.disconnect()
    } else {
        localASREngine.stop()
    }
    DispatchQueue.main.async {
        if let button = self.statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "yapyap")
        }
        self.overlayWindow.hide()
    }
}
```

- [ ] **Step 7: Add showNotConfiguredLocalAlert()**

Add after `showNotConfiguredAlert()`:

```swift
private func showNotConfiguredLocalAlert() {
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = L10n.notConfiguredLocalTitle
        alert.informativeText = L10n.notConfiguredLocalMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.openSettings)
        alert.addButton(withTitle: L10n.cancel)
        if alert.runModal() == .alertFirstButtonReturn {
            self.openSettings()
        }
    }
}
```

- [ ] **Step 8: Reload model when selectedModelId changes**

Add to `setupBindings()`:

```swift
SettingsStore.shared.$selectedModelId
    .receive(on: DispatchQueue.main)
    .sink { [weak self] modelId in
        guard let self, !modelId.isEmpty else { return }
        if let model = self.modelManager.model(for: modelId),
           let path = self.modelManager.modelPath(for: model) {
            self.localASREngine.loadModel(model, path: path)
        }
    }
    .store(in: &cancellables)
```

- [ ] **Step 9: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

Expected: Builds successfully. App defaults to online mode so existing behavior is unchanged.

- [ ] **Step 10: Commit**

```bash
git add yapyap/Sources/App.swift
git commit -m "feat: route audio to online or local ASR engine based on mode setting"
```

---

### Task 6: Update Settings UI with Model Management

**Files:**
- Modify: `yapyap/Sources/SettingsView.swift`

- [ ] **Step 1: Replace ASRTabView with redesigned version**

Replace the entire `ASRTabView` struct with:

```swift
// MARK: - ASR Tab

struct ASRTabView: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var showAccessKey = false
    @State private var testState: TestState = .idle

    enum TestState {
        case idle, testing
        case success(String)
        case failure(String)
    }

    private var isTestRunning: Bool {
        if case .testing = testState { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ASR Mode picker
            SectionCard(header: L10n.asrModeHeader) {
                Picker("", selection: $store.asrMode) {
                    ForEach(ASRMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(12)
            }

            if store.asrMode == .online {
                onlineSettingsSection
            } else {
                localModelsSection
            }
        }
    }

    // MARK: - Online Settings

    private var onlineSettingsSection: some View {
        SectionCard(
            header: L10n.asrApiHeader,
            trailing: AnyView(
                Link(L10n.getKey, destination: URL(string: "https://console.volcengine.com/speech/service/10038")!)
                    .font(.system(size: 11))
            )
        ) {
            CardRow(label: "App Key") {
                TextField("", text: $store.appKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }
            CardDivider()
            CardRow(label: "Access Key") {
                HStack(spacing: 4) {
                    if showAccessKey {
                        TextField("", text: $store.accessKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("", text: $store.accessKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { showAccessKey.toggle() }) {
                        Image(systemName: showAccessKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .frame(maxWidth: .infinity)
            }
            CardDivider()
            CardRow(label: "Resource ID") {
                Picker("", selection: $store.resourceId) {
                    Text(L10n.resourceHourly20).tag("volc.seedasr.sauc.duration")
                    Text(L10n.resourceConcurrent20).tag("volc.seedasr.sauc.concurrent")
                    Text(L10n.resourceHourly10).tag("volc.bigasr.sauc.duration")
                    Text(L10n.resourceConcurrent10).tag("volc.bigasr.sauc.concurrent")
                }
                .labelsHidden()
            }
            CardDivider()

            // Test connection row
            HStack {
                Button(action: runTest) {
                    HStack(spacing: 4) {
                        if case .testing = testState {
                            ProgressView().controlSize(.small)
                        }
                        Text(L10n.testConnection)
                    }
                }
                .disabled(store.appKey.isEmpty || store.accessKey.isEmpty || isTestRunning)

                Spacer()

                switch testState {
                case .idle:
                    EmptyView()
                case .testing:
                    Text(L10n.connecting)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                case .success(let msg):
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                case .failure:
                    EmptyView()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if case .failure(let msg) = testState {
                Text(msg)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(Color.red.opacity(0.06))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Local Models

    private var localModelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !modelManager.downloadedModels.isEmpty && store.selectedModelId.isEmpty {
                // Hint to select a model
                Text(L10n.noModelHint)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 2)
            }

            if modelManager.downloadedModels.isEmpty {
                Text(L10n.noModelHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }

            ForEach(modelManager.catalog) { model in
                ModelCardView(model: model)
            }
        }
    }

    // MARK: - Test Connection

    private func runTest() {
        testState = .testing
        ASRClient.testConnection(
            appKey: store.appKey,
            accessKey: store.accessKey,
            resourceId: store.resourceId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let msg):
                    testState = .success(msg)
                case .failure(let error):
                    testState = .failure(error.localizedDescription)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add ModelCardView**

Add after `ASRTabView`:

```swift
// MARK: - Model Card

struct ModelCardView: View {
    let model: ModelInfo
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var modelManager = ModelManager.shared

    private var isDownloaded: Bool { modelManager.isDownloaded(model.id) }
    private var isDownloading: Bool { modelManager.downloadProgress[model.id] != nil }
    private var isExtracting: Bool { modelManager.isExtracting[model.id] == true }
    private var isActive: Bool { store.selectedModelId == model.id }
    private var progress: Double { modelManager.downloadProgress[model.id] ?? 0 }
    private var speed: String { modelManager.downloadSpeed[model.id] ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(model.sizeDescription)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(model.languagesDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isExtracting {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text(L10n.modelExtracting)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if isDownloading {
                    Button(L10n.cancelDownload) {
                        modelManager.cancelDownload(model.id)
                    }
                    .controlSize(.small)
                } else if isDownloaded {
                    HStack(spacing: 8) {
                        if isActive {
                            Text(L10n.modelActive)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fontWeight(.medium)
                        } else {
                            Button(action: { store.selectedModelId = model.id }) {
                                Text(L10n.lang == .zh ? "选择" : "Select")
                            }
                            .controlSize(.small)
                        }
                        Button(action: { modelManager.delete(model.id) }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button(L10n.modelDownload) {
                        modelManager.download(model.id)
                    }
                    .controlSize(.small)
                }
            }
            .padding(12)

            // Download progress bar
            if isDownloading {
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !speed.isEmpty {
                            Text(speed)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isActive ? Color.orange.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.5),
                    lineWidth: isActive ? 1.5 : 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
bash scripts/rebuild-and-open.sh
```

Expected: App launches. Open Settings → Model tab. Should see ASR Mode picker (Online/Local). Switching to Local shows three model cards with Download buttons. Switching to Online shows the existing Doubao API fields.

- [ ] **Step 4: Commit**

```bash
git add yapyap/Sources/SettingsView.swift
git commit -m "feat: add model management UI with download progress and mode switching"
```

---

### Task 7: Build Verification and Integration Testing

**Files:** None (manual testing)

- [ ] **Step 1: Full build verification**

```bash
bash scripts/rebuild-and-open.sh
```

Expected: Clean build, app launches in menu bar.

- [ ] **Step 2: Test online mode (existing functionality)**

1. Open Settings → Model tab
2. Verify ASR Mode defaults to "Online (Doubao)"
3. Verify existing API key fields are visible
4. Test recording with fn key → should work as before

- [ ] **Step 3: Test model download**

1. Switch to "Local" mode in Settings
2. Click "Download" on SenseVoice Small (~160 MB, smallest model)
3. Verify progress bar shows percentage and speed
4. Verify extraction completes and model shows as "Downloaded"
5. Click "Select" to activate it

- [ ] **Step 4: Test local transcription**

1. With a local model selected and active
2. Press and hold fn → should start recording
3. Speak something → should see text appear in overlay (updated every ~1.5s)
4. Release fn → final text should be injected at cursor

- [ ] **Step 5: Test model management**

1. Test Cancel during download
2. Test Delete of a downloaded model
3. Test switching between models
4. Test switching between Online and Local modes
5. Test that deleting the active model clears the selection

- [ ] **Step 6: Commit any fixes**

```bash
git add -A
git commit -m "fix: integration testing fixes for offline model transcription"
```
