import Foundation

enum MetadataKeywordNormalizer {
    static func normalized(_ value: String) -> String {
        var seenKeywords = Set<String>()
        var keywords: [String] = []

        for keyword in keywordParts(value) {
            let normalizedKey = keyword.lowercased()
            guard !seenKeywords.contains(normalizedKey) else {
                continue
            }

            seenKeywords.insert(normalizedKey)
            keywords.append(keyword)
        }

        return keywords.joined(separator: ",")
    }

    private static func keywordParts(_ value: String) -> [String] {
        value
            .replacingOccurrences(of: "\n", with: ",")
            .replacingOccurrences(of: ";", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
