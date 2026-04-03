import Foundation
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "AIProcessor")

enum AIProcessor {
    /// Send text to OpenAI-compatible API for correction.
    /// Calls completion on main thread with corrected text, or original on failure.
    static func process(
        text: String,
        completion: @escaping (String) -> Void
    ) {
        let settings = SettingsStore.shared
        guard settings.aiEnabled,
              !settings.aiApiKey.isEmpty,
              !settings.aiBaseURL.isEmpty,
              !text.isEmpty else {
            logger.info("AI processing skipped (disabled or not configured)")
            completion(text)
            return
        }

        let baseURL = settings.aiBaseURL.hasSuffix("/")
            ? String(settings.aiBaseURL.dropLast())
            : settings.aiBaseURL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            logger.error("Invalid AI API URL: \(settings.aiBaseURL)")
            completion(text)
            return
        }

        var systemPrompt = settings.aiPrompt.isEmpty
            ? "You are a text correction assistant. Fix any speech recognition errors and grammar issues in the following text. Return only the corrected text, nothing else."
            : settings.aiPrompt

        if !settings.aiTerms.isEmpty {
            let termsList = settings.aiTerms.map { "- \($0)" }.joined(separator: "\n")
            systemPrompt += "\n\nIMPORTANT: The following terms/proper nouns must be used exactly as written when they appear in the text. Speech recognition may have misrecognized them:\n\(termsList)"
        }

        let body: [String: Any] = [
            "model": settings.aiModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": 4096
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            logger.error("Failed to serialize AI request")
            completion(text)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.aiApiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 15

        logger.info("Sending to AI: model=\(settings.aiModel), text=\(text.prefix(50))...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                logger.error("AI request failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(text) }
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                if let data, let raw = String(data: data, encoding: .utf8) {
                    logger.error("AI response parse failed: \(raw.prefix(200))")
                }
                DispatchQueue.main.async { completion(text) }
                return
            }

            let corrected = content.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.info("AI corrected: \(corrected.prefix(50))...")
            DispatchQueue.main.async { completion(corrected) }
        }.resume()
    }
}
