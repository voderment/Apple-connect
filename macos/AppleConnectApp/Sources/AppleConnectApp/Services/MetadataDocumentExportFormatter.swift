import Foundation

enum MetadataDocumentExportFormatter {
    static func json(document: MetadataDocument) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        return String(decoding: data, as: UTF8.self)
    }
}
