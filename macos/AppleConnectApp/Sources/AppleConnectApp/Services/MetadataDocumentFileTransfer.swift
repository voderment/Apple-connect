import Foundation

enum MetadataDocumentFileTransfer {
    static func write(document: MetadataDocument, to url: URL) throws {
        let json = try MetadataDocumentExportFormatter.json(document: document)
        try json.write(to: url, atomically: true, encoding: .utf8)
    }

    static func read(from url: URL) throws -> MetadataDocument {
        let json = try String(contentsOf: url, encoding: .utf8)
        return try MetadataDocumentImportFormatter.document(from: json)
    }
}
