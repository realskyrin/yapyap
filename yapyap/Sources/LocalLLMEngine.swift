import Foundation
import MLX
import MLXLMCommon
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "LocalLLMEngine")

enum LocalLLMEngine {
    private static let generateParameters = GenerateParameters(
        maxTokens: 4096,
        temperature: 0.3
    )
    private static let thinkBlockRegex = try! NSRegularExpression(
        pattern: "<think>[\\s\\S]*?</think>",
        options: []
    )
    private static let sessionManager = SessionManager()

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

        // Resolved via SettingsStore so UI, online path, and local path stay in sync.
        var systemPrompt = settings.effectiveSystemPrompt

        if !settings.aiTerms.isEmpty {
            let termsList = settings.aiTerms.map { "- \($0)" }.joined(separator: "\n")
            systemPrompt += """


            Glossary — proper nouns and technical terms the speaker may use. ONLY substitute \
            when the input clearly contains a misrecognized form of one of these. Do NOT insert \
            these into the output if the input doesn't match them:
            \(termsList)
            """
        }

        logger.info("Local LLM processing: \(text.prefix(50))...")

        Task {
            do {
                let raw = try await sessionManager.respond(
                    to: text,
                    container: container,
                    instructions: systemPrompt
                )
                let corrected = sanitize(raw, fallback: text)
                logger.info("Local LLM result: \(corrected.prefix(50))...")

                DispatchQueue.main.async { completion(corrected) }
            } catch {
                logger.error("Local LLM generation failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(text) }
            }
        }
    }

    static func reset() {
        Task {
            await sessionManager.reset()
        }
    }

    /// Defensive cleanup: strip thinking blocks, stray control tokens,
    /// and fall back to the original text if the model returned nothing.
    private static func sanitize(_ raw: String, fallback: String) -> String {
        var result = raw

        // Strip <think>...</think> blocks in case a thinking variant leaks them.
        let range = NSRange(result.startIndex..., in: result)
        result = thinkBlockRegex.stringByReplacingMatches(
            in: result,
            options: [],
            range: range,
            withTemplate: ""
        )

        // Strip stray /no_think directives the model may echo.
        result = result.replacingOccurrences(of: "/no_think", with: "", options: .caseInsensitive)

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result.isEmpty ? fallback : result
    }

    private actor SessionManager {
        private var session: ChatSession?
        private var modelIdentity: ObjectIdentifier?
        private var currentInstructions: String?

        func respond(
            to prompt: String,
            container: ModelContainer,
            instructions: String
        ) async throws -> String {
            let session = prepareSession(container: container, instructions: instructions)

            do {
                // Qwen3-Instruct-2507 is a non-thinking model — don't append /no_think,
                // it gets echoed back as literal text.
                let raw = try await session.respond(to: prompt)
                await clearSessionState(session)
                return raw
            } catch {
                await clearSessionState(session)
                throw error
            }
        }

        func reset() async {
            guard let session else {
                modelIdentity = nil
                currentInstructions = nil
                Memory.clearCache()
                return
            }

            await clearSessionState(session)
            self.session = nil
            modelIdentity = nil
            currentInstructions = nil
        }

        private func prepareSession(
            container: ModelContainer,
            instructions: String
        ) -> ChatSession {
            let identity = ObjectIdentifier(container)

            if session == nil || modelIdentity != identity {
                session = ChatSession(
                    container,
                    instructions: instructions,
                    generateParameters: LocalLLMEngine.generateParameters
                )
                modelIdentity = identity
                currentInstructions = instructions
                return session!
            }

            if currentInstructions != instructions {
                session?.instructions = instructions
                currentInstructions = instructions
            }

            return session!
        }

        private func clearSessionState(_ session: ChatSession) async {
            await session.clear()
            await session.synchronize()
            Memory.clearCache()
        }
    }
}
