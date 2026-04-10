import Foundation
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "LocalASREngine")

class LocalASREngine {
    var onTextUpdate: ((String) -> Void)?

    private var recognizer: SherpaOnnxOfflineRecognizer?
    private var currentStream: SherpaOnnxOfflineStreamWrapper?
    private var pendingSamples: [Float] = []
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

        // SherpaOnnxOfflineRecognizer init calls fatalError on failure,
        // so we trust that valid model paths produce a valid recognizer.
        recognizer = SherpaOnnxOfflineRecognizer(config: &config)

        logger.info("Model loaded successfully: \(model.name)")
    }

    func unloadModel() {
        // Wait for any in-flight inference to finish before niling the recognizer
        inferenceTimer?.cancel()
        inferenceTimer = nil
        isSessionActive = false
        inferenceQueue.sync {}  // barrier: waits for pending work to drain
        teardownSession()
        recognizer = nil
        logger.info("Model unloaded")
    }

    var isModelLoaded: Bool {
        recognizer != nil
    }

    // MARK: - Session

    func start() {
        guard let recognizer else {
            logger.error("Cannot start: no model loaded")
            return
        }

        bufferLock.lock()
        pendingSamples.removeAll(keepingCapacity: false)
        bufferLock.unlock()
        currentStream = recognizer.createStream()
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
        pendingSamples.append(contentsOf: samples)
        bufferLock.unlock()
    }

    func stop(completion: (() -> Void)? = nil) {
        guard isSessionActive else {
            teardownSession()
            completion?()
            return
        }
        isSessionActive = false

        inferenceTimer?.cancel()
        inferenceTimer = nil

        // Run final inference with complete audio, then notify caller
        inferenceQueue.async { [weak self] in
            self?.runInference(force: true)
            self?.teardownSession()
            DispatchQueue.main.async { completion?() }
        }

        logger.info("Recording session stopped")
    }

    // MARK: - Inference

    private func runInference(force: Bool = false) {
        guard let recognizer, !isInferenceRunning else { return }

        if currentStream == nil {
            currentStream = recognizer.createStream()
        }
        guard let stream = currentStream else { return }

        bufferLock.lock()
        let samples = pendingSamples
        pendingSamples.removeAll(keepingCapacity: true)
        bufferLock.unlock()

        guard force || !samples.isEmpty else { return }

        isInferenceRunning = true
        defer { isInferenceRunning = false }

        if !samples.isEmpty {
            stream.acceptWaveform(samples: samples, sampleRate: 16_000)
        }

        recognizer.decode(stream: stream)
        let result = recognizer.getResult(stream: stream)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

        logger.debug("Inference result (+\(samples.count) samples): \(text.prefix(100))")

        if !text.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onTextUpdate?(text)
            }
        }
    }

    private func teardownSession() {
        bufferLock.lock()
        pendingSamples.removeAll(keepingCapacity: false)
        bufferLock.unlock()
        currentStream = nil
        isInferenceRunning = false
    }
}
