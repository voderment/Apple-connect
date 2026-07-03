import Foundation

@MainActor
protocol LLMServicing {
    func testConnection(configuration: LLMProviderConfiguration) async throws -> String
    func generateText(configuration: LLMProviderConfiguration, messages: [LLMMessage]) async throws -> String
}

struct LLMMessage: Equatable, Codable {
    var role: String
    var content: String
}

struct OpenAICompatibleLLMService: LLMServicing {
    var urlSession: URLSession = .shared

    func testConnection(configuration: LLMProviderConfiguration) async throws -> String {
        try await generateText(
            configuration: configuration,
            messages: [
                LLMMessage(role: "system", content: "You are a connectivity check. Reply with OK."),
                LLMMessage(role: "user", content: "Return OK.")
            ]
        )
    }

    func generateText(configuration: LLMProviderConfiguration, messages: [LLMMessage]) async throws -> String {
        guard configuration.isConfigured else {
            throw LLMError.missingConfiguration
        }

        let baseURL = configuration.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ChatCompletionRequest(
            model: configuration.model,
            messages: messages.map { ChatCompletionMessage(role: $0.role, content: $0.content) },
            temperature: configuration.temperature
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? JSONDecoder().decode(ChatCompletionErrorResponse.self, from: data)
            throw LLMError.httpStatus(httpResponse.statusCode, payload?.error.message)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw LLMError.emptyResponse
        }

        return content
    }
}

struct DemoLLMService: LLMServicing {
    func testConnection(configuration: LLMProviderConfiguration) async throws -> String {
        "OK demo"
    }

    func generateText(configuration: LLMProviderConfiguration, messages: [LLMMessage]) async throws -> String {
        let prompt = messages.map(\.content).joined(separator: "\n").lowercased()

        if prompt.contains("translate this app store metadata") {
            return structuredMetadataJSON(
                name: "Fact Demo",
                subtitle: "Localized release prep",
                description: "A localized demo workspace for preparing App Store metadata, review checks, and handoff reports.",
                promotionalText: "Prepare localized App Store copy with a guided demo flow.",
                whatsNew: "Added localized review prep, safer drafts, and shareable handoff reports."
            )
        }

        if prompt.contains("revise this localization") {
            return structuredMetadataJSON(
                name: "Fact Demo",
                subtitle: "Review-ready release prep",
                description: "Prepare App Store metadata with clear validation, review guidance, localization checks, and shareable handoff reports.",
                promotionalText: "Review release metadata with clearer checks and safer handoff tools.",
                whatsNew: "Improved review preparation, URL checks, and metadata handoff reports."
            )
        }

        if prompt.contains("suggest a comma-separated") {
            return "release,metadata,review,localization"
        }

        if prompt.contains("draft promotional text") {
            return "Prepare App Store metadata with clearer checks and safer handoffs."
        }

        if prompt.contains("draft a clear what's new") {
            return "Improved review prep, validation guidance, and shareable metadata handoff reports."
        }

        return "Prepare App Store metadata with a focused release workspace for localized copy, review checks, and handoff reports."
    }

    private func structuredMetadataJSON(
        name: String,
        subtitle: String,
        description: String,
        promotionalText: String,
        whatsNew: String
    ) -> String {
        """
        {
          "appInfo": {
            "name": "\(name)",
            "subtitle": "\(subtitle)",
            "privacyPolicyURL": "https://example.com/privacy",
            "privacyChoicesURL": "",
            "privacyPolicyText": ""
          },
          "version": {
            "description": "\(description)",
            "keywords": "release,metadata,review,localization",
            "marketingURL": "https://example.com",
            "promotionalText": "\(promotionalText)",
            "supportURL": "https://example.com/support",
            "whatsNew": "\(whatsNew)"
          }
        }
        """
    }
}

enum LLMError: LocalizedError {
    case missingConfiguration
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int, String?)
    case emptyResponse
    case invalidStructuredResponse

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Add an API key, base URL, and model first."
        case .invalidBaseURL:
            "The model provider base URL is invalid."
        case .invalidResponse:
            "The model provider returned an invalid response."
        case let .httpStatus(status, message):
            message ?? "The model provider returned HTTP \(status)."
        case .emptyResponse:
            "The model provider returned an empty response."
        case .invalidStructuredResponse:
            "The model provider returned content that could not be read as structured metadata."
        }
    }
}

private struct ChatCompletionRequest: Encodable {
    var model: String
    var messages: [ChatCompletionMessage]
    var temperature: Double
}

private struct ChatCompletionMessage: Codable {
    var role: String
    var content: String
}

private struct ChatCompletionResponse: Decodable {
    var choices: [ChatCompletionChoice]
}

private struct ChatCompletionChoice: Decodable {
    var message: ChatCompletionMessage
}

private struct ChatCompletionErrorResponse: Decodable {
    var error: ChatCompletionError
}

private struct ChatCompletionError: Decodable {
    var message: String?
}
