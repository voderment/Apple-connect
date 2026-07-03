import Foundation

struct ASCAppAttributes: Decodable {
    var name: String
    var bundleId: String
    var sku: String
    var primaryLocale: String
}

struct ASCAppInfoAttributes: Decodable {
    var state: String?
    var appStoreState: String?
}

struct ASCAppInfoLocalizationAttributes: Decodable {
    var locale: String
    var name: String?
    var subtitle: String?
    var privacyPolicyUrl: String?
    var privacyChoicesUrl: String?
    var privacyPolicyText: String?
}

struct ASCAppStoreVersionAttributes: Decodable {
    var platform: String
    var versionString: String
    var appVersionState: String
    var appStoreState: String
    var createdDate: Date
}

struct ASCBuildAttributes: Decodable {
    var version: String?
    var uploadedDate: Date?
    var processingState: String?
    var iconAssetToken: ASCImageAsset?
}

struct ASCImageAsset: Decodable {
    var templateUrl: String?
    var width: Int?
    var height: Int?

    var resolvedURL: URL? {
        guard var templateUrl else {
            return nil
        }

        let resolvedWidth = String(width ?? 512)
        let resolvedHeight = String(height ?? width ?? 512)
        templateUrl = templateUrl
            .replacingOccurrences(of: "{w}", with: resolvedWidth)
            .replacingOccurrences(of: "{h}", with: resolvedHeight)
            .replacingOccurrences(of: "{f}", with: "png")

        return URL(string: templateUrl)
    }
}

struct ASCVersionLocalizationAttributes: Decodable {
    var locale: String
    var description: String?
    var keywords: String?
    var marketingUrl: String?
    var promotionalText: String?
    var supportUrl: String?
    var whatsNew: String?
}

struct ASCAppInfoLocalizationRequestAttributes: Encodable {
    var locale: String?
    var name: String?
    var subtitle: String?
    var privacyPolicyUrl: String?
    var privacyChoicesUrl: String?
    var privacyPolicyText: String?
}

struct ASCVersionLocalizationRequestAttributes: Encodable {
    var locale: String?
    var description: String?
    var keywords: String?
    var marketingUrl: String?
    var promotionalText: String?
    var supportUrl: String?
    var whatsNew: String?
}
