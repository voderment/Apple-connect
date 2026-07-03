import Foundation

struct MetadataDraft: Equatable, Codable {
    var document: MetadataDocument
    var savedAt: Date
}

protocol MetadataDraftPersisting {
    func loadDraft(appID: String, versionID: String) throws -> MetadataDraft?
    func saveDraft(_ draft: MetadataDraft, appID: String, versionID: String) throws
    func deleteDraft(appID: String, versionID: String) throws
}

struct FileMetadataDraftStore: MetadataDraftPersisting {
    private let folderURL: URL
    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        folderURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.folderURL = folderURL ?? Self.defaultFolderURL(fileManager: fileManager)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadDraft(appID: String, versionID: String) throws -> MetadataDraft? {
        let url = draftURL(appID: appID, versionID: versionID)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(MetadataDraft.self, from: data)
    }

    func saveDraft(_ draft: MetadataDraft, appID: String, versionID: String) throws {
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(draft)
        try data.write(to: draftURL(appID: appID, versionID: versionID), options: .atomic)
    }

    func deleteDraft(appID: String, versionID: String) throws {
        let url = draftURL(appID: appID, versionID: versionID)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    private func draftURL(appID: String, versionID: String) -> URL {
        folderURL.appendingPathComponent("\(safePathComponent(appID))--\(safePathComponent(versionID)).json")
    }

    private func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let characters = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "-"
        }
        return characters.joined()
    }

    private static func defaultFolderURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent(AppConstants.productName, isDirectory: true)
            .appendingPathComponent("Drafts", isDirectory: true)
    }
}
