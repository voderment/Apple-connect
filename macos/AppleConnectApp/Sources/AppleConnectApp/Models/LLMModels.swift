import Foundation

enum LLMProviderKind: String, CaseIterable, Identifiable, Codable {
    case aliyunBailian
    case openAICompatible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aliyunBailian:
            "Alibaba Cloud Model Studio"
        case .openAICompatible:
            "OpenAI Compatible"
        }
    }
}

struct LLMProviderConfiguration: Equatable, Codable {
    var kind: LLMProviderKind
    var apiKey: String
    var baseURL: String
    var model: String
    var temperature: Double
    var isEnabled: Bool

    static let aliyunBailianDefault = LLMProviderConfiguration(
        kind: .aliyunBailian,
        apiKey: "",
        baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
        model: "qwen-plus",
        temperature: 0.4,
        isEnabled: false
    )

    static let demoFixture = LLMProviderConfiguration(
        kind: .openAICompatible,
        apiKey: "demo",
        baseURL: "https://demo.local/v1",
        model: "demo-fixture",
        temperature: 0,
        isEnabled: true
    )

    var isConfigured: Bool {
        !apiKey.isEmpty && !baseURL.isEmpty && !model.isEmpty
    }
}

enum MetadataAIAction: String, CaseIterable, Identifiable {
    case rewriteDescription
    case suggestKeywords
    case draftPromotionalText
    case draftWhatsNew
    case reviewPolish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rewriteDescription:
            "Rewrite Description"
        case .suggestKeywords:
            "Suggest Keywords"
        case .draftPromotionalText:
            "Draft Promo Text"
        case .draftWhatsNew:
            "Draft What's New"
        case .reviewPolish:
            "Review Polish"
        }
    }

    var systemImage: String {
        switch self {
        case .rewriteDescription:
            "text.alignleft"
        case .suggestKeywords:
            "tag"
        case .draftPromotionalText:
            "megaphone"
        case .draftWhatsNew:
            "sparkles"
        case .reviewPolish:
            "checkmark.seal"
        }
    }

    var resultName: String {
        switch self {
        case .rewriteDescription:
            "description"
        case .suggestKeywords:
            "keywords"
        case .draftPromotionalText:
            "promotional text"
        case .draftWhatsNew:
            "What's New"
        case .reviewPolish:
            "review-ready metadata"
        }
    }
}
