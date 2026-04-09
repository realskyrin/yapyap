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

        let delegate = DownloadDelegate(modelId: modelId, manager: self)
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
                    // Clean up the temp archive
                    try? FileManager.default.removeItem(at: location)
                    self.refreshDownloadedState()

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
        guard now.timeIntervalSince(lastProgressTime) >= 0.1 else { return }
        lastProgressTime = now

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

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
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".tar.bz2")
        try? FileManager.default.copyItem(at: location, to: tempURL)
        manager?.handleDownloadComplete(modelId, location: tempURL)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error, (error as NSError).code != NSURLErrorCancelled {
            manager?.handleDownloadError(modelId, error: error)
        }
    }
}
