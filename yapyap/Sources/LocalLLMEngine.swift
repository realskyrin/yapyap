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
