import Foundation
import MLXLLM
import MLXLMCommon
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "LLMModelManager")

class LLMModelManager: ObservableObject {
    static let shared = LLMModelManager()

    static let modelId = "mlx-community/Qwen3-4B-Instruct-2507-4bit"

    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var isDownloaded: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private(set) var modelContainer: ModelContainer?

    private var loadTask: Task<Void, Never>?
    private var diskPollTimer: Timer?

    // Approximate total download size in bytes for Qwen3-4B-Instruct-2507-4bit (~2.1 GB)
    private let expectedTotalBytes: Int64 = 2_252_000_000

    private init() {
        checkDownloadedState()
    }

    // MARK: - State

    private func checkDownloadedState() {
        isDownloaded = hasCompleteDownload()
    }

    /// Check if a complete model snapshot exists in the HuggingFace cache.
    /// A partial/interrupted download creates the directory but won't have a config.json in snapshots.
    private func hasCompleteDownload() -> Bool {
        let modelDirName = Self.modelId.replacingOccurrences(of: "/", with: "--")
        let snapshotsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
            .appendingPathComponent("models--\(modelDirName)")
            .appendingPathComponent("snapshots")
        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotsDir, includingPropertiesForKeys: nil) else { return false }
        return snapshots.contains {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("config.json").path)
        }
    }

    private func hubCacheDirectory() -> URL? {
        let modelDirName = Self.modelId.replacingOccurrences(of: "/", with: "--")
        let cacheBase = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
            .appendingPathComponent("models--\(modelDirName)")
        return FileManager.default.fileExists(atPath: cacheBase.path) ? cacheBase : nil
    }

    // MARK: - Download & Load

    func downloadAndLoad() {
        guard !isDownloading, !isLoading else { return }

        startDiskPolling()

        loadTask = Task { @MainActor in
            isDownloading = true
            downloadProgress = 0
            error = nil

            do {
                let config = ModelConfiguration(id: Self.modelId)

                logger.info("Starting download/load: \(Self.modelId)")

                let container = try await LLMModelFactory.shared.loadContainer(
                    configuration: config
                ) { _ in
                    // Per-file callback ignored; we poll disk instead
                }

                self.modelContainer = container
                self.isDownloaded = true
                self.isDownloading = false
                self.downloadProgress = 1.0
                self.stopDiskPolling()
                logger.info("Model loaded successfully")
            } catch {
                logger.error("Model load failed: \(error.localizedDescription)")
                self.error = error.localizedDescription
                self.isDownloading = false
                self.stopDiskPolling()
            }
        }
    }

    func cancelDownload() {
        loadTask?.cancel()
        loadTask = nil
        stopDiskPolling()
        isDownloading = false
        isLoading = false
        downloadProgress = 0
    }

    // MARK: - Disk polling for smooth progress

    private func startDiskPolling() {
        stopDiskPolling()
        diskPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let bytes = self.currentDiskBytes()
            let progress = min(Double(bytes) / Double(self.expectedTotalBytes), 0.99)
            DispatchQueue.main.async {
                self.downloadProgress = progress
            }
        }
    }

    private func stopDiskPolling() {
        diskPollTimer?.invalidate()
        diskPollTimer = nil
    }

    private func currentDiskBytes() -> Int64 {
        let modelDirName = Self.modelId.replacingOccurrences(of: "/", with: "--")
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
            .appendingPathComponent("models--\(modelDirName)")
        guard let enumerator = FileManager.default.enumerator(
            at: cacheDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
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

    /// Load model into memory if already downloaded but not loaded (e.g. after app restart)
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
