import Foundation

struct AppStoreConnectAPIClient {
    var baseURL: URL
    var tokenProvider: ASCJWTTokenProvider
    var urlSession: URLSession

    init(
        baseURL: URL = URL(string: "https://api.appstoreconnect.apple.com")!,
        tokenProvider: ASCJWTTokenProvider,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.urlSession = urlSession
    }

    func request<Response: Decodable>(
        _ pathOrURL: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> Response {
        let request = try await makeRequest(
            pathOrURL,
            queryItems: queryItems,
            method: method,
            body: body
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ASCAPIError.invalidResponse
        }

        if httpResponse.statusCode == 204, Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? JSONDecoder().decode(ASCErrorPayload.self, from: data)
            throw ASCAPIError.httpStatus(httpResponse.statusCode, payload)
        }

        return try JSONDecoder.asc.decode(Response.self, from: data)
    }

    func paginate<Attributes: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> [ASCResource<Attributes>] {
        var resources: [ASCResource<Attributes>] = []
        var nextURL: String? = path
        var nextQueryItems = queryItems

        while let pageURL = nextURL {
            let page: ASCPage<Attributes> = try await request(pageURL, queryItems: nextQueryItems)
            resources.append(contentsOf: page.data)
            nextURL = page.links?.next
            nextQueryItems = []
        }

        return resources
    }

    func listApps(limit: Int = 200) async throws -> [ASCResource<ASCAppAttributes>] {
        try await paginate(
            "/v1/apps",
            queryItems: [
                URLQueryItem(name: "fields[apps]", value: "name,bundleId,sku,primaryLocale"),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "sort", value: "name")
            ]
        )
    }

    func listAppInfos(appID: String) async throws -> [ASCResource<ASCAppInfoAttributes>] {
        try await paginate(
            "/v1/apps/\(appID.urlPathEncoded)/appInfos",
            queryItems: [
                URLQueryItem(name: "fields[appInfos]", value: "state,appStoreState"),
                URLQueryItem(name: "limit", value: "200")
            ]
        )
    }

    func listBuilds(appID: String, limit: Int = 10) async throws -> [ASCResource<ASCBuildAttributes>] {
        try await paginate(
            "/v1/apps/\(appID.urlPathEncoded)/builds",
            queryItems: [
                URLQueryItem(name: "fields[builds]", value: "version,uploadedDate,processingState,iconAssetToken"),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "sort", value: "-uploadedDate")
            ]
        )
    }

    func listAppInfoLocalizations(
        appInfoID: String,
        locales: [String] = []
    ) async throws -> [ASCResource<ASCAppInfoLocalizationAttributes>] {
        try await paginate(
            "/v1/appInfos/\(appInfoID.urlPathEncoded)/appInfoLocalizations",
            queryItems: [
                URLQueryItem(name: "filter[locale]", value: locales.isEmpty ? nil : locales.joined(separator: ",")),
                URLQueryItem(name: "fields[appInfoLocalizations]", value: "locale,name,subtitle,privacyPolicyUrl,privacyChoicesUrl,privacyPolicyText"),
                URLQueryItem(name: "limit", value: "200")
            ].filter { $0.value != nil }
        )
    }

    func listVersions(appID: String) async throws -> [ASCResource<ASCAppStoreVersionAttributes>] {
        try await paginate(
            "/v1/apps/\(appID.urlPathEncoded)/appStoreVersions",
            queryItems: [
                URLQueryItem(name: "fields[appStoreVersions]", value: "platform,versionString,appVersionState,appStoreState,createdDate"),
                URLQueryItem(name: "limit", value: "200")
            ]
        )
    }

    func listVersionLocalizations(
        versionID: String,
        locales: [String] = []
    ) async throws -> [ASCResource<ASCVersionLocalizationAttributes>] {
        try await paginate(
            "/v1/appStoreVersions/\(versionID.urlPathEncoded)/appStoreVersionLocalizations",
            queryItems: [
                URLQueryItem(name: "filter[locale]", value: locales.isEmpty ? nil : locales.joined(separator: ",")),
                URLQueryItem(name: "fields[appStoreVersionLocalizations]", value: "locale,description,keywords,marketingUrl,promotionalText,supportUrl,whatsNew"),
                URLQueryItem(name: "limit", value: "200")
            ].filter { $0.value != nil }
        )
    }

    func createAppInfoLocalization(
        appInfoID: String,
        attributes: ASCAppInfoLocalizationRequestAttributes
    ) async throws -> ASCSingleResource<ASCAppInfoLocalizationAttributes> {
        try await request(
            "/v1/appInfoLocalizations",
            method: "POST",
            body: ASCMutationRequest(
                data: ASCMutationData(
                    type: "appInfoLocalizations",
                    id: nil,
                    attributes: attributes,
                    relationships: [
                        "appInfo": ASCRelationship(data: ASCRelationshipData(type: "appInfos", id: appInfoID))
                    ]
                )
            )
        )
    }

    func updateAppInfoLocalization(
        localizationID: String,
        attributes: ASCAppInfoLocalizationRequestAttributes
    ) async throws -> ASCSingleResource<ASCAppInfoLocalizationAttributes> {
        try await request(
            "/v1/appInfoLocalizations/\(localizationID.urlPathEncoded)",
            method: "PATCH",
            body: ASCMutationRequest(
                data: ASCMutationData(
                    type: "appInfoLocalizations",
                    id: localizationID,
                    attributes: attributes,
                    relationships: nil
                )
            )
        )
    }

    func createVersionLocalization(
        versionID: String,
        attributes: ASCVersionLocalizationRequestAttributes
    ) async throws -> ASCSingleResource<ASCVersionLocalizationAttributes> {
        try await request(
            "/v1/appStoreVersionLocalizations",
            method: "POST",
            body: ASCMutationRequest(
                data: ASCMutationData(
                    type: "appStoreVersionLocalizations",
                    id: nil,
                    attributes: attributes,
                    relationships: [
                        "appStoreVersion": ASCRelationship(data: ASCRelationshipData(type: "appStoreVersions", id: versionID))
                    ]
                )
            )
        )
    }

    func updateVersionLocalization(
        localizationID: String,
        attributes: ASCVersionLocalizationRequestAttributes
    ) async throws -> ASCSingleResource<ASCVersionLocalizationAttributes> {
        try await request(
            "/v1/appStoreVersionLocalizations/\(localizationID.urlPathEncoded)",
            method: "PATCH",
            body: ASCMutationRequest(
                data: ASCMutationData(
                    type: "appStoreVersionLocalizations",
                    id: localizationID,
                    attributes: attributes,
                    relationships: nil
                )
            )
        )
    }

    private func makeRequest(
        _ pathOrURL: String,
        queryItems: [URLQueryItem],
        method: String,
        body: Encodable?
    ) async throws -> URLRequest {
        let token = try await tokenProvider.token()
        var url = pathOrURL.hasPrefix("http")
            ? URL(string: pathOrURL)!
            : URL(string: pathOrURL, relativeTo: baseURL)!.absoluteURL

        if !queryItems.isEmpty {
            url.append(queryItems: queryItems)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        return request
    }
}

struct AppIconLookupClient {
    var baseURL: URL
    var urlSession: URLSession

    init(
        baseURL: URL = URL(string: "https://itunes.apple.com/lookup")!,
        urlSession: URLSession = Self.makeURLSession()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func applyingIconURLs(to apps: [ConnectApp]) async -> [ConnectApp] {
        guard !apps.isEmpty else {
            return apps
        }

        do {
            let iconURLs = try await lookupIconURLs(for: apps)
            return apps.map { app in
                var enrichedApp = app
                if enrichedApp.iconURL == nil {
                    enrichedApp.iconURL = iconURLs[app.id] ?? iconURLs[app.bundleID]
                }
                return enrichedApp
            }
        } catch {
            return apps
        }
    }

    private func lookupIconURLs(for apps: [ConnectApp]) async throws -> [String: URL] {
        let appleIDs = apps.map(\.id).filter { !$0.isEmpty }.joined(separator: ",")
        guard !appleIDs.isEmpty else {
            return [:]
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: appleIDs),
            URLQueryItem(name: "entity", value: "software")
        ]

        guard let url = components?.url else {
            return [:]
        }

        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return [:]
        }

        let payload = try JSONDecoder().decode(AppStoreLookupResponse.self, from: data)
        var iconURLs: [String: URL] = [:]

        for result in payload.results {
            guard let artworkURL = result.bestArtworkURL else {
                continue
            }

            if let trackID = result.trackId {
                iconURLs[String(trackID)] = artworkURL
            }

            if let bundleID = result.bundleId {
                iconURLs[bundleID] = artworkURL
            }
        }

        return iconURLs
    }

    private static func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }
}

private struct AppStoreLookupResponse: Decodable {
    var results: [AppStoreLookupResult]
}

private struct AppStoreLookupResult: Decodable {
    var trackId: Int?
    var bundleId: String?
    var artworkUrl60: String?
    var artworkUrl100: String?
    var artworkUrl512: String?

    var bestArtworkURL: URL? {
        for value in [artworkUrl512, artworkUrl100, artworkUrl60] {
            if let value, let url = URL(string: value) {
                return url
            }
        }

        return nil
    }
}

struct ASCPage<Attributes: Decodable>: Decodable {
    var data: [ASCResource<Attributes>]
    var links: ASCLinks?
}

struct ASCSingleResource<Attributes: Decodable>: Decodable {
    var data: ASCResource<Attributes>
}

struct ASCResource<Attributes: Decodable>: Decodable {
    var id: String
    var type: String
    var attributes: Attributes
}

struct ASCLinks: Decodable {
    var next: String?
}

struct EmptyResponse: Decodable {}

struct ASCErrorPayload: Decodable, Equatable {
    var errors: [ASCErrorItem]
}

struct ASCErrorItem: Decodable, Equatable {
    var code: String?
    var title: String?
    var detail: String?
}

enum ASCAPIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, ASCErrorPayload?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "App Store Connect returned an invalid response."
        case let .httpStatus(status, payload):
            if let first = payload?.errors.first {
                return [String(status), first.code, first.title, first.detail]
                    .compactMap { $0 }
                    .joined(separator: ": ")
            }

            return "App Store Connect API error \(status)."
        }
    }
}

struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

struct ASCMutationRequest<Attributes: Encodable>: Encodable {
    var data: ASCMutationData<Attributes>
}

struct ASCMutationData<Attributes: Encodable>: Encodable {
    var type: String
    var id: String?
    var attributes: Attributes
    var relationships: [String: ASCRelationship]?
}

struct ASCRelationship: Encodable {
    var data: ASCRelationshipData
}

struct ASCRelationshipData: Encodable {
    var type: String
    var id: String
}

extension JSONDecoder {
    static var asc: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension String {
    var urlPathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}
