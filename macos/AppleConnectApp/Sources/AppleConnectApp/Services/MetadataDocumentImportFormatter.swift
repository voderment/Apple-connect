import Foundation

enum MetadataDocumentImportFormatter {
    static func document(from json: String) throws -> MetadataDocument {
        guard let data = json.data(using: .utf8) else {
            throw MetadataDocumentImportError.invalidText
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MetadataDocument.self, from: data)
    }
}

enum MetadataDocumentImportError: LocalizedError {
    case invalidText

    var errorDescription: String? {
        switch self {
        case .invalidText:
            "Metadata JSON could not be read as UTF-8 text."
        }
    }
}
