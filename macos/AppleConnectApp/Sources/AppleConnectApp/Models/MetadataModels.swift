import Foundation

struct MetadataDocument: Equatable, Codable {
    var localizations: [LocaleMetadata]
    var pulledAt: Date
}

struct LocaleMetadata: Identifiable, Equatable, Codable {
    var id: String { locale }
    var locale: String
    var appInfo: AppInfoMetadata
    var version: VersionMetadata

    var completedFieldCount: Int {
        appInfo.completedFieldCount + version.completedFieldCount
    }

    var totalFieldCount: Int {
        appInfo.totalFieldCount + version.totalFieldCount
    }
}

struct AppInfoMetadata: Equatable, Codable {
    var name: String
    var subtitle: String
    var privacyPolicyURL: String
    var privacyChoicesURL: String
    var privacyPolicyText: String

    var completedFieldCount: Int {
        [name, subtitle, privacyPolicyURL, privacyChoicesURL, privacyPolicyText]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    var totalFieldCount: Int { 5 }
}

struct VersionMetadata: Equatable, Codable {
    var description: String
    var keywords: String
    var marketingURL: String
    var promotionalText: String
    var supportURL: String
    var whatsNew: String

    var completedFieldCount: Int {
        [description, keywords, marketingURL, promotionalText, supportURL, whatsNew]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    var totalFieldCount: Int { 6 }
}

enum MetadataResource: String, Codable {
    case appInfoLocalization
    case appStoreVersionLocalization
}

enum MetadataActionKind: String, Codable {
    case create
    case update
    case skip
}

enum ValidationSeverity: String, Codable {
    case error
    case warning
}

struct ValidationIssue: Identifiable, Equatable, Codable {
    var severity: ValidationSeverity
    var locale: String
    var field: String
    var message: String

    var id: String {
        [locale, field, severity.rawValue, message].joined(separator: "|")
    }

    var remediation: String {
        let lowercasedMessage = message.lowercased()

        if lowercasedMessage.contains("2-30 characters") {
            return "Use a customer-facing app name between 2 and 30 characters."
        }

        if lowercasedMessage.contains("subtitle") && lowercasedMessage.contains("30 characters") {
            return "Shorten the subtitle to 30 characters or fewer."
        }

        if lowercasedMessage.contains("4000 characters") {
            return "Trim the field below 4000 characters before saving."
        }

        if lowercasedMessage.contains("170 characters") {
            return "Trim promotional text to 170 characters or fewer."
        }

        if lowercasedMessage.contains("100 utf-8 bytes") {
            return "Keep keywords comma-separated and under 100 UTF-8 bytes."
        }

        if lowercasedMessage.contains("full http(s) url") {
            return "Paste a complete URL that starts with https://."
        }

        if lowercasedMessage.contains("use https") {
            return "Replace http:// with https:// for public App Store links."
        }

        if lowercasedMessage.contains("placeholder") {
            return "Replace placeholder text with final localized copy."
        }

        if lowercasedMessage.contains("beta")
            || lowercasedMessage.contains("testflight")
            || lowercasedMessage.contains("internal-testing") {
            return "Use customer-facing release language instead of internal test terms."
        }

        if lowercasedMessage.contains("ranking")
            || lowercasedMessage.contains("guarantee") {
            return "Remove or substantiate ranking and guarantee claims."
        }

        if lowercasedMessage.contains("keywords are required") {
            return "Add a focused comma-separated keyword list."
        }

        if lowercasedMessage.contains("support url is required") {
            return "Add a public support URL for this locale."
        }

        if lowercasedMessage.contains("duplicated") {
            return "Keep only one metadata entry for this locale."
        }

        if lowercasedMessage.contains("locale is required") {
            return "Enter a valid App Store locale identifier."
        }

        return "Review this field before saving."
    }
}

struct MetadataChangeAction: Identifiable, Equatable, Codable {
    var locale: String
    var resource: MetadataResource
    var kind: MetadataActionKind
    var fields: [String]

    var id: String {
        [locale, resource.rawValue, kind.rawValue, fields.joined(separator: ",")].joined(separator: "|")
    }
}

struct MetadataPlan: Equatable, Codable {
    var issues: [ValidationIssue]
    var actions: [MetadataChangeAction]

    static let empty = MetadataPlan(issues: [], actions: [])

    var hasBlockingIssues: Bool {
        issues.contains { $0.severity == .error }
    }

    var visibleActions: [MetadataChangeAction] {
        actions.filter { $0.kind != .skip }
    }
}

enum ReleaseReadinessLevel: String, Codable, CaseIterable {
    case ready
    case warning
    case blocking
}

struct ReleaseReadinessItem: Identifiable, Equatable, Codable {
    var level: ReleaseReadinessLevel
    var title: String
    var detail: String
    var systemImage: String

    var id: String {
        [level.rawValue, title, detail].joined(separator: "|")
    }
}

struct ReviewChecklistItem: Identifiable, Equatable, Codable {
    var level: ReleaseReadinessLevel
    var title: String
    var detail: String
    var remediation: String
    var systemImage: String
    var affectedLocales: [String]
    var affectedLabel: String = "Locales"

    var id: String {
        [level.rawValue, title, detail, affectedLabel, affectedLocales.joined(separator: ",")].joined(separator: "|")
    }
}

enum ReviewFixKind: String, Codable {
    case upgradeHTTPS
    case normalizeKeywords
}

struct ReviewFixProposal: Identifiable, Equatable, Codable {
    var kind: ReviewFixKind
    var locale: String
    var field: String
    var title: String
    var detail: String
    var before: String
    var after: String

    var id: String {
        [kind.rawValue, locale, field, before, after].joined(separator: "|")
    }
}

enum ReviewPrepNextActionKind: String, Codable {
    case selectVersion
    case reviewFixes
    case resolveBlockers
    case reviewWarnings
    case saveDraft
    case exportHandoff
}

struct ReviewPrepNextAction: Equatable, Codable {
    var kind: ReviewPrepNextActionKind
    var title: String
    var detail: String
    var systemImage: String
    var level: ReleaseReadinessLevel
}

struct ReviewPrepSummary: Equatable, Codable {
    var blockerCount: Int
    var warningCount: Int
    var proposedFixCount: Int
    var draftActionCount: Int
    var nextAction: ReviewPrepNextAction
}
