import AppKit
import AVFoundation
import Foundation

enum StoreMediaAssetInspectionError: LocalizedError {
    case unsupportedImageFormat
    case unsupportedPreviewFormat
    case unreadableImage
    case unreadableVideo

    var errorDescription: String? {
        switch self {
        case .unsupportedImageFormat:
            "Screenshots must be .jpeg, .jpg, or .png files."
        case .unsupportedPreviewFormat:
            "App previews must be .mov, .m4v, or .mp4 files."
        case .unreadableImage:
            "Fact could not read the image dimensions."
        case .unreadableVideo:
            "Fact could not read the video dimensions."
        }
    }
}

enum StoreMediaAssetInspector {
    static func inspect(url: URL, kind: StoreMediaAssetKind) async throws -> StoreMediaAsset {
        let fileSize = try fileSizeBytes(url)

        switch kind {
        case .screenshot:
            guard ["jpeg", "jpg", "png"].contains(url.pathExtension.lowercased()) else {
                throw StoreMediaAssetInspectionError.unsupportedImageFormat
            }
            let size = try imageSize(url)
            return StoreMediaAsset(
                kind: kind,
                fileName: url.lastPathComponent,
                filePath: url.path,
                width: size.width,
                height: size.height,
                fileSizeBytes: fileSize,
                durationSeconds: nil,
                importedAt: .now
            )
        case .appPreview:
            guard ["mov", "m4v", "mp4"].contains(url.pathExtension.lowercased()) else {
                throw StoreMediaAssetInspectionError.unsupportedPreviewFormat
            }
            let video = try await videoInfo(url)
            return StoreMediaAsset(
                kind: kind,
                fileName: url.lastPathComponent,
                filePath: url.path,
                width: video.width,
                height: video.height,
                fileSizeBytes: fileSize,
                durationSeconds: video.durationSeconds,
                importedAt: .now
            )
        }
    }

    private static func fileSizeBytes(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    private static func imageSize(_ url: URL) throws -> PixelSize {
        let data = try Data(contentsOf: url)
        if let representation = NSBitmapImageRep(data: data) {
            return PixelSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }

        if let image = NSImage(contentsOf: url),
           let representation = image.representations.first {
            return PixelSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }

        throw StoreMediaAssetInspectionError.unreadableImage
    }

    private static func videoInfo(_ url: URL) async throws -> (width: Int?, height: Int?, durationSeconds: Double?) {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let track = tracks.first else {
            throw StoreMediaAssetInspectionError.unreadableVideo
        }

        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let transformedSize = naturalSize.applying(preferredTransform)
        let width = Int(abs(transformedSize.width).rounded())
        let height = Int(abs(transformedSize.height).rounded())
        let seconds = CMTimeGetSeconds(duration)

        return (
            width: width > 0 ? width : nil,
            height: height > 0 ? height : nil,
            durationSeconds: seconds.isFinite ? seconds : nil
        )
    }
}

enum StoreMediaRequirementValidator {
    static func issues(for catalog: StoreMediaCatalog) -> [StoreMediaValidationIssue] {
        var issues: [StoreMediaValidationIssue] = []

        for locale in catalog.locales {
            for spec in catalog.deviceSpecs {
                let set = catalog.set(locale: locale, deviceID: spec.id)
                validateScreenshots(set.screenshots, locale: locale, spec: spec, into: &issues)
                validatePreviews(set.appPreviews, locale: locale, spec: spec, into: &issues)
            }
        }

        return issues
    }

    static func summary(for catalog: StoreMediaCatalog) -> StoreMediaValidationSummary {
        let issues = issues(for: catalog)
        let requiredSets = catalog.locales.flatMap { locale in
            catalog.deviceSpecs.filter(\.isRequired).map { spec in
                catalog.set(locale: locale, deviceID: spec.id)
            }
        }
        let completeRequiredSets = requiredSets.filter { !$0.screenshots.isEmpty }
        let screenshotCount = catalog.sets.reduce(0) { $0 + $1.screenshots.count }
        let previewCount = catalog.sets.reduce(0) { $0 + $1.appPreviews.count }

        return StoreMediaValidationSummary(
            requiredSetCount: requiredSets.count,
            completeRequiredSetCount: completeRequiredSets.count,
            screenshotCount: screenshotCount,
            previewCount: previewCount,
            blockingCount: issues.filter { $0.severity == .blocking }.count,
            warningCount: issues.filter { $0.severity == .warning }.count
        )
    }

    private static func validateScreenshots(
        _ screenshots: [StoreMediaAsset],
        locale: String,
        spec: StoreMediaDeviceSpec,
        into issues: inout [StoreMediaValidationIssue]
    ) {
        if screenshots.isEmpty, spec.isRequired {
            issues.append(
                StoreMediaValidationIssue(
                    severity: .blocking,
                    locale: locale,
                    deviceID: spec.id,
                    kind: .screenshot,
                    title: "Missing required screenshots",
                    detail: "Upload 1-10 screenshots for \(spec.displayName)."
                )
            )
        }

        if screenshots.count > 10 {
            issues.append(
                StoreMediaValidationIssue(
                    severity: .blocking,
                    locale: locale,
                    deviceID: spec.id,
                    kind: .screenshot,
                    title: "Too many screenshots",
                    detail: "\(spec.displayName) has \(screenshots.count) screenshots; App Store Connect accepts up to 10."
                )
            )
        }

        for asset in screenshots {
            if !["jpeg", "jpg", "png"].contains(asset.fileExtension) {
                issues.append(
                    StoreMediaValidationIssue(
                        severity: .blocking,
                        locale: locale,
                        deviceID: spec.id,
                        kind: .screenshot,
                        title: "Unsupported screenshot format",
                        detail: "\(asset.fileName) must be .jpeg, .jpg, or .png."
                    )
                )
            }

            guard let width = asset.width, let height = asset.height else {
                issues.append(
                    StoreMediaValidationIssue(
                        severity: .warning,
                        locale: locale,
                        deviceID: spec.id,
                        kind: .screenshot,
                        title: "Screenshot dimensions unavailable",
                        detail: "Fact could not inspect \(asset.fileName)."
                    )
                )
                continue
            }

            if !spec.acceptsScreenshot(width: width, height: height) {
                issues.append(
                    StoreMediaValidationIssue(
                        severity: .blocking,
                        locale: locale,
                        deviceID: spec.id,
                        kind: .screenshot,
                        title: "Screenshot size mismatch",
                        detail: "\(asset.fileName) is \(width) x \(height); expected \(spec.screenshotSizeSummary)."
                    )
                )
            }
        }
    }

    private static func validatePreviews(
        _ previews: [StoreMediaAsset],
        locale: String,
        spec: StoreMediaDeviceSpec,
        into issues: inout [StoreMediaValidationIssue]
    ) {
        guard !previews.isEmpty else {
            return
        }

        if previews.count > 3 {
            issues.append(
                StoreMediaValidationIssue(
                    severity: .blocking,
                    locale: locale,
                    deviceID: spec.id,
                    kind: .appPreview,
                    title: "Too many app previews",
                    detail: "\(spec.displayName) has \(previews.count) previews; App Store Connect accepts up to 3."
                )
            )
        }

        for asset in previews {
            if !["mov", "m4v", "mp4"].contains(asset.fileExtension) {
                issues.append(
                    StoreMediaValidationIssue(
                        severity: .blocking,
                        locale: locale,
                        deviceID: spec.id,
                        kind: .appPreview,
                        title: "Unsupported preview format",
                        detail: "\(asset.fileName) must be .mov, .m4v, or .mp4."
                    )
                )
            }

            if asset.fileSizeBytes > 500 * 1_024 * 1_024 {
                issues.append(
                    StoreMediaValidationIssue(
                        severity: .blocking,
                        locale: locale,
                        deviceID: spec.id,
                        kind: .appPreview,
                        title: "Preview file too large",
                        detail: "\(asset.fileName) is \(asset.fileSizeText); App Store Connect accepts up to 500 MB."
                    )
                )
            }

            if let duration = asset.durationSeconds, duration < 15 || duration > 30 {
                issues.append(
                    StoreMediaValidationIssue(
                        severity: .blocking,
                        locale: locale,
                        deviceID: spec.id,
                        kind: .appPreview,
                        title: "Preview duration mismatch",
                        detail: "\(asset.fileName) is \(Int(duration.rounded())) seconds; app previews must be 15-30 seconds."
                    )
                )
            }

            guard let width = asset.width, let height = asset.height, !spec.previewSizes.isEmpty else {
                continue
            }

            if !spec.acceptsPreview(width: width, height: height) {
                issues.append(
                    StoreMediaValidationIssue(
                        severity: .blocking,
                        locale: locale,
                        deviceID: spec.id,
                        kind: .appPreview,
                        title: "Preview size mismatch",
                        detail: "\(asset.fileName) is \(width) x \(height); expected \(spec.previewSizeSummary)."
                    )
                )
            }
        }
    }
}

enum MockStoreMediaCatalogFactory {
    static func catalog(app: ConnectApp?, version: AppStoreVersion?, locales: [String], isDemoMode: Bool) -> StoreMediaCatalog {
        let platform = version?.platform ?? "IOS"
        var catalog = StoreMediaCatalog.empty(locales: locales, platform: platform)

        guard isDemoMode else {
            seedPolishedAssets(in: &catalog)
            return catalog
        }

        if app?.id == "2234567890" {
            seedReviewDemoAssets(in: &catalog)
        } else {
            seedPolishedAssets(in: &catalog)
        }

        return catalog
    }

    private static func seedPolishedAssets(in catalog: inout StoreMediaCatalog) {
        for locale in catalog.locales {
            for spec in catalog.deviceSpecs where spec.isRequired {
                guard let size = spec.screenshotSizes.first else {
                    continue
                }
                catalog.add(
                    asset(
                        kind: .screenshot,
                        fileName: "\(locale)-\(spec.id)-01.png",
                        width: size.width,
                        height: size.height
                    ),
                    locale: locale,
                    deviceID: spec.id
                )
            }
        }
    }

    private static func seedReviewDemoAssets(in catalog: inout StoreMediaCatalog) {
        guard let firstSpec = catalog.deviceSpecs.first else {
            return
        }

        if catalog.locales.contains("en-US"), let size = firstSpec.screenshotSizes.first {
            catalog.add(
                asset(
                    kind: .screenshot,
                    fileName: "en-US-\(firstSpec.id)-hero.png",
                    width: size.width,
                    height: size.height
                ),
                locale: "en-US",
                deviceID: firstSpec.id
            )
            if let previewSize = firstSpec.previewSizes.first {
                catalog.add(
                    asset(
                        kind: .appPreview,
                        fileName: "en-US-\(firstSpec.id)-preview.mp4",
                        width: previewSize.width,
                        height: previewSize.height,
                        fileSizeBytes: 42 * 1_024 * 1_024,
                        durationSeconds: 22
                    ),
                    locale: "en-US",
                    deviceID: firstSpec.id
                )
            }
        }

        if catalog.locales.contains("es-MX") {
            catalog.add(
                asset(
                    kind: .screenshot,
                    fileName: "es-MX-\(firstSpec.id)-wrong-size.png",
                    width: 1200,
                    height: 2400
                ),
                locale: "es-MX",
                deviceID: firstSpec.id
            )
        }
    }

    private static func asset(
        kind: StoreMediaAssetKind,
        fileName: String,
        width: Int?,
        height: Int?,
        fileSizeBytes: Int64 = 2 * 1_024 * 1_024,
        durationSeconds: Double? = nil
    ) -> StoreMediaAsset {
        StoreMediaAsset(
            kind: kind,
            fileName: fileName,
            filePath: "/Demo/Media/\(fileName)",
            width: width,
            height: height,
            fileSizeBytes: fileSizeBytes,
            durationSeconds: durationSeconds,
            importedAt: .now
        )
    }
}
