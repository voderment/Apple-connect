import CryptoKit
import Foundation

struct ASCAuthConfiguration: Equatable {
    var keyID: String
    var issuerID: String
    var privateKeyPEM: String
    var tokenTTL: TimeInterval = 19 * 60
}

actor ASCJWTTokenProvider {
    private let configuration: ASCAuthConfiguration
    private var cachedToken: String?
    private var expiresAt = Date.distantPast

    init(configuration: ASCAuthConfiguration) {
        self.configuration = configuration
    }

    func token() throws -> String {
        if let cachedToken, Date.now < expiresAt.addingTimeInterval(-60) {
            return cachedToken
        }

        let token = try Self.makeToken(configuration: configuration, issuedAt: .now)
        cachedToken = token
        expiresAt = .now.addingTimeInterval(configuration.tokenTTL)
        return token
    }

    static func makeToken(configuration: ASCAuthConfiguration, issuedAt: Date) throws -> String {
        guard !configuration.keyID.isEmpty, !configuration.issuerID.isEmpty else {
            throw ServiceError.missingCredentials
        }

        let privateKey = try P256.Signing.PrivateKey(pemRepresentation: configuration.privateKeyPEM)
        let expiresAt = issuedAt.addingTimeInterval(configuration.tokenTTL)
        let header = JWTHeader(kid: configuration.keyID)
        let payload = JWTPayload(
            iss: configuration.issuerID,
            aud: "appstoreconnect-v1",
            iat: Int(issuedAt.timeIntervalSince1970),
            exp: Int(expiresAt.timeIntervalSince1970)
        )

        let encoder = JSONEncoder()
        let signingInput = try [
            encoder.encode(header).base64URLEncodedString(),
            encoder.encode(payload).base64URLEncodedString()
        ].joined(separator: ".")

        let signature = try privateKey.signature(for: Data(signingInput.utf8))
        return "\(signingInput).\(signature.rawRepresentation.base64URLEncodedString())"
    }
}

private struct JWTHeader: Encodable {
    var alg = "ES256"
    var kid: String
    var typ = "JWT"
}

private struct JWTPayload: Encodable {
    var iss: String
    var aud: String
    var iat: Int
    var exp: Int
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
