import Foundation
import MLX
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

    /// Directory where MLX's default HubApi materializes the snapshot (uses
    /// `.cachesDirectory` as `downloadBase`, matching `MLXLMCommon.defaultHubApi`).
    /// Passing this directly to `ModelConfiguration(directory:)` skips HubApi.snapshot()
    /// and therefore all HuggingFace HTTP requests — load succeeds even if the Hub is
    /// returning errors (e.g. 500s) for an already-downloaded model.
    private static func materializedModelDirectory() -> URL {
        let downloadBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return downloadBase.appending(component: "models").appending(component: Self.modelId)
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
                Self.flushPostLoadCache(label: "download")
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

    /// Return MLX's transient load-time buffers to the OS immediately after a
    /// successful model load. `loadContainer()` streams safetensors through
    /// intermediate buffers while placing the weights into their final MLX
    /// arrays; once the load completes those intermediate buffers are freed by
    /// Swift ARC, but — per the same behavior documented on `unload()` —
    /// MLX parks them in `cacheMemory` for reuse instead of releasing them to
    /// the OS. The result is a ~4 GB RSS peak (weights + leftover cache)
    /// that only drops back to ~2.2 GB later, when the first inference's
    /// `clearSessionState()` happens to flush the cache. Flushing here makes
    /// the drop happen right after load, before the user notices it.
    private static func flushPostLoadCache(label: String) {
        let before = MLX.Memory.snapshot()
        MLX.Memory.clearCache()
        let after = MLX.Memory.snapshot()
        let beforeActive = before.activeMemory / (1024 * 1024)
        let beforeCache = before.cacheMemory / (1024 * 1024)
        let afterActive = after.activeMemory / (1024 * 1024)
        let afterCache = after.cacheMemory / (1024 * 1024)
        logger.info("LLM post-load cache flush (\(label, privacy: .public)). MLX active=\(beforeActive, privacy: .public)→\(afterActive, privacy: .public)MB cache=\(beforeCache, privacy: .public)→\(afterCache, privacy: .public)MB")
    }

    /// Release the loaded model from memory while keeping the on-disk cache intact.
    /// Called when the user switches away from local AI so the MLX weights (~2.1 GB
    /// in unified memory) don't sit resident for the rest of the process lifetime.
    ///
    /// The teardown has two subtle requirements that an earlier version of this
    /// method got wrong:
    ///
    /// 1. **We must await the ChatSession tearing down before flushing the cache.**
    ///    `LocalLLMEngine`'s `SessionManager` holds a `ChatSession`, which holds a
    ///    strong reference to the `ModelContainer`. Setting our own property to
    ///    `nil` is not enough — the session keeps the weights alive. We call
    ///    `resetAndWait()` and only continue once the session has been nilled out.
    ///
    /// 2. **We must call `Memory.clearCache()` *after* the container is
    ///    deallocated.** MLX doesn't return freed buffers to the OS immediately:
    ///    on deallocation they move from `activeMemory` to `cacheMemory` (a
    ///    reusable buffer pool). The weights don't actually leave the process
    ///    until someone flushes that pool. Without this explicit call, Activity
    ///    Monitor keeps showing the ~2 GB footprint indefinitely.
    func unload() {
        guard modelContainer != nil || isLoading || loadTask != nil else { return }

        loadTask?.cancel()
        loadTask = nil

        let before = MLX.Memory.snapshot()
        let beforeActive = before.activeMemory / (1024 * 1024)
        let beforeCache = before.cacheMemory / (1024 * 1024)
        logger.info("LLM unload starting. MLX active=\(beforeActive, privacy: .public)MB cache=\(beforeCache, privacy: .public)MB")

        modelContainer = nil
        isLoading = false
        error = nil

        Task {
            // Wait for the SessionManager actor to drop its ChatSession. Only
            // after this point is the ModelContainer's last reference released
            // and the weights reclaimable.
            await LocalLLMEngine.resetAndWait()

            // Return cached MLX buffers (including the freed model weights that
            // just moved from active to cache) to the OS. Without this the RSS
            // footprint stays at the peak for the lifetime of the process.
            MLX.Memory.clearCache()

            let after = MLX.Memory.snapshot()
            let afterActive = after.activeMemory / (1024 * 1024)
            let afterCache = after.cacheMemory / (1024 * 1024)
            logger.info("LLM unload complete. MLX active=\(afterActive, privacy: .public)MB cache=\(afterCache, privacy: .public)MB")
        }
    }

    func delete() {
        unload()

        if let cacheDir = hubCacheDirectory() {
            try? FileManager.default.removeItem(at: cacheDir)
            logger.info("Deleted LLM model cache")
        }

        isDownloaded = false
    }

    /// Load model into memory if already downloaded but not loaded (e.g. after app restart)
    func ensureLoaded() {
        guard isDownloaded, modelContainer == nil, !isLoading else { return }

        isLoading = true
        error = nil
        loadTask = Task { @MainActor in
            do {
                // Use the materialized directory so MLX skips HubApi.snapshot() and
                // never touches HuggingFace. Prevents transient Hub 500s from breaking
                // loads of an already-downloaded model.
                let config = ModelConfiguration(directory: Self.materializedModelDirectory())
                let container = try await LLMModelFactory.shared.loadContainer(
                    configuration: config
                ) { _ in }

                self.modelContainer = container
                self.isLoading = false
                Self.flushPostLoadCache(label: "ensureLoaded")
                logger.info("Model loaded from local directory")
            } catch {
                logger.error("Model load failed: \(error.localizedDescription)")
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
