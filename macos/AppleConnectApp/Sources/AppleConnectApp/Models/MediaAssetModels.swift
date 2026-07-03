import Foundation

enum StoreMediaAssetKind: String, Codable, CaseIterable, Identifiable {
    case screenshot
    case appPreview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenshot:
            "Screenshot"
        case .appPreview:
            "App Preview"
        }
    }
}

struct PixelSize: Hashable, Codable {
    var width: Int
    var height: Int

    var label: String {
        "\(width) x \(height)"
    }
}

struct StoreMediaDeviceSpec: Identifiable, Hashable, Codable {
    var id: String
    var platform: String
    var displayName: String
    var requirement: String
    var isRequired: Bool
    var screenshotSizes: [PixelSize]
    var previewSizes: [PixelSize]

    var screenshotSizeSummary: String {
        screenshotSizes.map(\.label).joined(separator: " / ")
    }

    var previewSizeSummary: String {
        guard !previewSizes.isEmpty else {
            return "Not supported"
        }

        return previewSizes.map(\.label).joined(separator: " / ")
    }

    func acceptsScreenshot(width: Int, height: Int) -> Bool {
        screenshotSizes.contains { $0.width == width && $0.height == height }
    }

    func acceptsPreview(width: Int, height: Int) -> Bool {
        previewSizes.contains { $0.width == width && $0.height == height }
    }
}

extension StoreMediaDeviceSpec {
    static func recommended(for platform: String) -> [StoreMediaDeviceSpec] {
        switch platform.uppercased() {
        case "MAC_OS", "MACOS":
            [mac]
        case "TV_OS", "TVOS":
            [appleTV]
        case "VISION_OS", "VISIONOS":
            [visionPro]
        case "WATCH_OS", "WATCHOS":
            [appleWatch]
        default:
            [iphone69, iphone65, ipad13]
        }
    }

    static let iphone69 = StoreMediaDeviceSpec(
        id: "iphone-6-9",
        platform: "IOS",
        displayName: "iPhone 6.9\"",
        requirement: "Required baseline for current iPhone screenshots.",
        isRequired: true,
        screenshotSizes: [
            PixelSize(width: 1260, height: 2736),
            PixelSize(width: 2736, height: 1260),
            PixelSize(width: 1290, height: 2796),
            PixelSize(width: 2796, height: 1290),
            PixelSize(width: 1320, height: 2868),
            PixelSize(width: 2868, height: 1320)
        ],
        previewSizes: [
            PixelSize(width: 886, height: 1920),
            PixelSize(width: 1920, height: 886)
        ]
    )

    static let iphone65 = StoreMediaDeviceSpec(
        id: "iphone-6-5",
        platform: "IOS",
        displayName: "iPhone 6.5\"",
        requirement: "Required if 6.9\" screenshots are not provided; useful for custom Media Manager control.",
        isRequired: false,
        screenshotSizes: [
            PixelSize(width: 1284, height: 2778),
            PixelSize(width: 2778, height: 1284),
            PixelSize(width: 1242, height: 2688),
            PixelSize(width: 2688, height: 1242)
        ],
        previewSizes: [
            PixelSize(width: 886, height: 1920),
            PixelSize(width: 1920, height: 886)
        ]
    )

    static let ipad13 = StoreMediaDeviceSpec(
        id: "ipad-13",
        platform: "IOS",
        displayName: "iPad 13\"",
        requirement: "Required if the app runs on iPad.",
        isRequired: true,
        screenshotSizes: [
            PixelSize(width: 2064, height: 2752),
            PixelSize(width: 2752, height: 2064),
            PixelSize(width: 2048, height: 2732),
            PixelSize(width: 2732, height: 2048)
        ],
        previewSizes: [
            PixelSize(width: 1200, height: 1600),
            PixelSize(width: 1600, height: 1200)
        ]
    )

    static let mac = StoreMediaDeviceSpec(
        id: "mac",
        platform: "MAC_OS",
        displayName: "Mac",
        requirement: "Required for Mac apps; screenshots must use a 16:10 ratio.",
        isRequired: true,
        screenshotSizes: [
            PixelSize(width: 1280, height: 800),
            PixelSize(width: 1440, height: 900),
            PixelSize(width: 2560, height: 1600),
            PixelSize(width: 2880, height: 1800)
        ],
        previewSizes: [
            PixelSize(width: 1920, height: 1080)
        ]
    )

    static let appleTV = StoreMediaDeviceSpec(
        id: "apple-tv",
        platform: "TV_OS",
        displayName: "Apple TV",
        requirement: "Required for Apple TV apps.",
        isRequired: true,
        screenshotSizes: [
            PixelSize(width: 1920, height: 1080),
            PixelSize(width: 3840, height: 2160)
        ],
        previewSizes: [
            PixelSize(width: 1920, height: 1080)
        ]
    )

    static let visionPro = StoreMediaDeviceSpec(
        id: "vision-pro",
        platform: "VISION_OS",
        displayName: "Apple Vision Pro",
        requirement: "Required for Apple Vision Pro apps.",
        isRequired: true,
        screenshotSizes: [
            PixelSize(width: 3840, height: 2160)
        ],
        previewSizes: [
            PixelSize(width: 1920, height: 1080)
        ]
    )

    static let appleWatch = StoreMediaDeviceSpec(
        id: "apple-watch",
        platform: "WATCH_OS",
        displayName: "Apple Watch",
        requirement: "Required for Apple Watch apps; use one size consistently across all localizations.",
        isRequired: true,
        screenshotSizes: [
            PixelSize(width: 422, height: 514),
            PixelSize(width: 410, height: 502),
            PixelSize(width: 416, height: 496),
            PixelSize(width: 396, height: 484),
            PixelSize(width: 368, height: 448),
            PixelSize(width: 312, height: 390)
        ],
        previewSizes: []
    )
}

struct StoreMediaAsset: Identifiable, Equatable, Codable {
    var id = UUID()
    var kind: StoreMediaAssetKind
    var fileName: String
    var filePath: String
    var width: Int?
    var height: Int?
    var fileSizeBytes: Int64
    var durationSeconds: Double?
    var importedAt: Date

    var fileExtension: String {
        URL(fileURLWithPath: filePath).pathExtension.lowercased()
    }

    var dimensionText: String {
        guard let width, let height else {
            return "Unknown size"
        }

        return "\(width) x \(height)"
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    var durationText: String {
        guard let durationSeconds else {
            return "No duration"
        }

        return "\(Int(durationSeconds.rounded()))s"
    }
}

struct StoreMediaSet: Identifiable, Equatable, Codable {
    var locale: String
    var deviceID: String
    var screenshots: [StoreMediaAsset]
    var appPreviews: [StoreMediaAsset]

    var id: String {
        "\(locale)|\(deviceID)"
    }
}

struct StoreMediaCatalog: Equatable, Codable {
    var platform: String
    var locales: [String]
    var deviceSpecs: [StoreMediaDeviceSpec]
    var sets: [StoreMediaSet]

    static func empty(locales: [String], platform: String) -> StoreMediaCatalog {
        let normalizedLocales = locales.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let specs = StoreMediaDeviceSpec.recommended(for: platform)
        return StoreMediaCatalog(
            platform: platform,
            locales: normalizedLocales,
            deviceSpecs: specs,
            sets: normalizedLocales.flatMap { locale in
                specs.map { spec in
                    StoreMediaSet(locale: locale, deviceID: spec.id, screenshots: [], appPreviews: [])
                }
            }
        )
    }

    func set(locale: String, deviceID: String) -> StoreMediaSet {
        sets.first { $0.locale == locale && $0.deviceID == deviceID }
            ?? StoreMediaSet(locale: locale, deviceID: deviceID, screenshots: [], appPreviews: [])
    }

    func deviceSpec(id: String) -> StoreMediaDeviceSpec? {
        deviceSpecs.first { $0.id == id }
    }

    mutating func add(_ asset: StoreMediaAsset, locale: String, deviceID: String) {
        ensureSet(locale: locale, deviceID: deviceID)
        guard let index = sets.firstIndex(where: { $0.locale == locale && $0.deviceID == deviceID }) else {
            return
        }

        switch asset.kind {
        case .screenshot:
            sets[index].screenshots.append(asset)
        case .appPreview:
            sets[index].appPreviews.append(asset)
        }
    }

    mutating func remove(assetID: StoreMediaAsset.ID, locale: String, deviceID: String, kind: StoreMediaAssetKind) {
        guard let index = sets.firstIndex(where: { $0.locale == locale && $0.deviceID == deviceID }) else {
            return
        }

        switch kind {
        case .screenshot:
            sets[index].screenshots.removeAll { $0.id == assetID }
        case .appPreview:
            sets[index].appPreviews.removeAll { $0.id == assetID }
        }
    }

    mutating func ensureLocale(_ locale: String) {
        guard !locales.contains(locale) else {
            return
        }

        locales.append(locale)
        locales.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        for spec in deviceSpecs {
            ensureSet(locale: locale, deviceID: spec.id)
        }
    }

    private mutating func ensureSet(locale: String, deviceID: String) {
        guard !sets.contains(where: { $0.locale == locale && $0.deviceID == deviceID }) else {
            return
        }

        sets.append(StoreMediaSet(locale: locale, deviceID: deviceID, screenshots: [], appPreviews: []))
    }
}

enum StoreMediaValidationSeverity: String, Codable {
    case blocking
    case warning
}

struct StoreMediaValidationIssue: Identifiable, Equatable, Codable {
    var severity: StoreMediaValidationSeverity
    var locale: String
    var deviceID: String
    var kind: StoreMediaAssetKind
    var title: String
    var detail: String

    var id: String {
        [severity.rawValue, locale, deviceID, kind.rawValue, title, detail].joined(separator: "|")
    }
}

struct StoreMediaValidationSummary: Equatable, Codable {
    var requiredSetCount: Int
    var completeRequiredSetCount: Int
    var screenshotCount: Int
    var previewCount: Int
    var blockingCount: Int
    var warningCount: Int

    var isReady: Bool {
        blockingCount == 0 && requiredSetCount == completeRequiredSetCount
    }
}
