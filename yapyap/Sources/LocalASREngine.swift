import Foundation
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "LocalASREngine")

class LocalASREngine {
    var onTextUpdate: ((String) -> Void)?

    private var recognizer: SherpaOnnxOfflineRecognizer?
    private var currentStream: SherpaOnnxOfflineStreamWrapper?
    private var isSessionActive = false
    private let inferenceQueue = DispatchQueue(label: "cn.skyrin.yapyap.localASR", qos: .userInitiated)

    // App-side endpoint detection. We don't currently ship a dedicated VAD model,
    // so segment utterances using audio energy and only decode on sentence-like pauses.
    private let sampleRate: Double = 16_000
    private let speechLevelThreshold: Float = 0.015
    private let endpointSilenceDuration: TimeInterval = 0.9
    private let minimumUtteranceDuration: TimeInterval = 0.25

    private var transcript = ""
    private var utteranceDuration: TimeInterval = 0
    private var trailingSilenceDuration: TimeInterval = 0
    private var utteranceHasSpeech = false

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
        inferenceQueue.sync {
            isSessionActive = false
            teardownSession(resetTranscript: true)
            recognizer = nil
        }
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

        inferenceQueue.sync {
            teardownSession(resetTranscript: true)
            isSessionActive = true
        }

        logger.info("Recording session started")
    }

    func feedAudio(_ data: Data) {
        // Convert Int16 PCM data to Float samples normalized to [-1, 1]
        let int16Count = data.count / MemoryLayout<Int16>.size
        let samples: [Float] = data.withUnsafeBytes { raw in
            let int16Ptr = raw.bindMemory(to: Int16.self)
            return (0..<int16Count).map { Float(int16Ptr[$0]) / 32768.0 }
        }

        inferenceQueue.async { [weak self] in
            self?.processChunk(samples)
        }
    }

    func stop(completion: (() -> Void)? = nil) {
        inferenceQueue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion?() }
                return
            }

            guard self.isSessionActive else {
                self.teardownSession(resetTranscript: true)
                DispatchQueue.main.async { completion?() }
                return
            }

            self.isSessionActive = false
            self.finalizeCurrentUtteranceIfNeeded(reason: "stop")
            self.teardownSession(resetTranscript: true)
            DispatchQueue.main.async { completion?() }
        }

        logger.info("Recording session stopped")
    }

    // MARK: - Segmentation / Inference

    private func processChunk(_ samples: [Float]) {
        guard isSessionActive, let recognizer, !samples.isEmpty else { return }

        let level = rms(samples)
        let hasSpeech = level >= speechLevelThreshold
        let chunkDuration = Double(samples.count) / sampleRate

        if hasSpeech && currentStream == nil {
            currentStream = recognizer.createStream()
        }

        guard let stream = currentStream else {
            return
        }

        stream.acceptWaveform(samples: samples, sampleRate: Int(sampleRate))
        utteranceDuration += chunkDuration

        if hasSpeech {
            utteranceHasSpeech = true
            trailingSilenceDuration = 0
        } else if utteranceHasSpeech {
            trailingSilenceDuration += chunkDuration
        }

        let reachedEndpoint = utteranceHasSpeech
            && utteranceDuration >= minimumUtteranceDuration
            && trailingSilenceDuration >= endpointSilenceDuration

        if reachedEndpoint {
            finalizeCurrentUtteranceIfNeeded(reason: "endpoint")
        }
    }

    private func finalizeCurrentUtteranceIfNeeded(reason: String) {
        guard let recognizer, let stream = currentStream, utteranceHasSpeech else {
            resetCurrentUtterance()
            return
        }

        recognizer.decode(stream: stream)
        let result = recognizer.getResult(stream: stream)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

        logger.debug(
            "Inference result (\(reason), \(Int(self.utteranceDuration * 1000)) ms utterance): \(text.prefix(100))"
        )

        if !text.isEmpty {
            transcript = Self.appendSegment(text, to: transcript)
            let fullText = transcript
            DispatchQueue.main.async { [weak self] in
                self?.onTextUpdate?(fullText)
            }
        }

        resetCurrentUtterance()
    }

    private func resetCurrentUtterance() {
        currentStream = nil
        utteranceDuration = 0
        trailingSilenceDuration = 0
        utteranceHasSpeech = false
    }

    private func teardownSession(resetTranscript: Bool) {
        resetCurrentUtterance()
        if resetTranscript {
            transcript.removeAll(keepingCapacity: false)
        }
    }

    private func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        return sqrt(sum / Float(samples.count))
    }

    private static func appendSegment(_ segment: String, to transcript: String) -> String {
        guard !segment.isEmpty else { return transcript }
        guard !transcript.isEmpty else { return segment }

        let needsSpace = needsSpaceBetween(transcript.last, and: segment.first)
        return transcript + (needsSpace ? " " : "") + segment
    }

    private static func needsSpaceBetween(_ lhs: Character?, and rhs: Character?) -> Bool {
        guard let lhs, let rhs else { return false }
        if lhs.isWhitespace || rhs.isWhitespace {
            return false
        }

        let lhsScalar = lhs.unicodeScalars.first
        let rhsScalar = rhs.unicodeScalars.first

        let lhsIsASCIIWord = lhsScalar.map { CharacterSet.alphanumerics.contains($0) && $0.isASCII } ?? false
        let rhsIsASCIIWord = rhsScalar.map { CharacterSet.alphanumerics.contains($0) && $0.isASCII } ?? false
        let lhsIsSentencePunctuation = ".!?,:;".contains(lhs)

        return (lhsIsASCIIWord && rhsIsASCIIWord) || (lhsIsSentencePunctuation && rhsIsASCIIWord)
    }
}
