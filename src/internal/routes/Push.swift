
import Foundation

final class Push: DescopePush, Route {
    let client: DescopeClient

    init(client: DescopeClient) {
        self.client = client
    }

    func enroll(token: String, development: Bool, refreshJwt: String) async throws(DescopeError) {
        let provider = development ? "apndev" : "apn"
        try await client.pushEnrollDevice(provider: provider, token: token, device: SystemInfo.device, refreshJwt: refreshJwt)
    }

    func enroll(deviceToken: Data, refreshJwt: String) async throws(DescopeError) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined() // device token data to hex
        try await enroll(token: token, development: APNsEnvironment.isDevelopment, refreshJwt: refreshJwt)
    }

    func finish(transactionId: String, approved: Bool, refreshJwt: String) async throws(DescopeError) {
        try await client.pushSignInFinish(transactionId: transactionId, approved: approved, refreshJwt: refreshJwt)
    }

    func cibaRequest(from userInfo: [AnyHashable: Any], session: DescopeSession, allowedHosts: [String]) -> DescopeCIBARequest? {
        let aps = userInfo["aps"] as? [String: Any]
        guard aps?["category"] as? String == DescopeCIBARequest.category else { return nil }

        // user info is never legitimate here, and parsers disagree on the host of URLs like "https://a\@b"
        guard let string = userInfo["url"] as? String, let url = URL(string: string), url.scheme == "https", url.user == nil, url.password == nil, let host = url.host?.lowercased() else {
            logger.error("Ignoring CIBA push without a valid https flow URL")
            return nil
        }
        guard trustedHosts(adding: allowedHosts).contains(host) else {
            logger.error("Ignoring CIBA push with a flow URL on an untrusted host", host)
            return nil
        }
        guard let projectId = userInfo["projectId"] as? String, projectId == client.config.projectId else {
            logger.error("Ignoring CIBA push for a different project")
            return nil
        }
        guard let userId = userInfo["userId"] as? String, userId == session.user.userId else {
            logger.error("Ignoring CIBA push for a different user")
            return nil
        }

        let alert = aps?["alert"] as? [String: Any]
        let body = alert?["body"] as? String ?? aps?["alert"] as? String
        return DescopeCIBARequest(url: url, userId: userId, projectId: projectId, title: alert?["title"] as? String, body: body)
    }

    func signInRequest(from userInfo: [AnyHashable: Any], session: DescopeSession) -> DescopePushSignInRequest? {
        let aps = userInfo["aps"] as? [String: Any]
        guard aps?["category"] as? String == DescopePushSignInRequest.category else { return nil }
        guard let transactionId = userInfo["transactionId"] as? String, !transactionId.isEmpty else {
            logger.error("Ignoring push sign-in request without a transaction id")
            return nil
        }
        guard let userId = userInfo["userId"] as? String, userId == session.user.userId else {
            logger.error("Ignoring push sign-in request for a different user")
            return nil
        }
        return DescopePushSignInRequest(transactionId: transactionId, userId: userId)
    }
    
    private func trustedHosts(adding allowedHosts: [String]) -> Set<String> {
        var hosts = Set(allowedHosts.map { $0.lowercased() })
        if let host = URL(string: client.baseURL)?.host?.lowercased() {
            hosts.insert(host)
        }
        return hosts
    }
}

enum APNsEnvironment {
    static let isDevelopment: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return isDevelopment(provisioningProfile: embeddedProvisioningProfile())
        #endif
    }()

    /// App Store and TestFlight builds have no embedded profile and always use production APNs.
    static func isDevelopment(provisioningProfile: Data?) -> Bool {
        // the profile is a signed CMS envelope with the plist stored in plain text inside it
        guard let data = provisioningProfile,
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else { return false }
        let plist = Data(data[start.lowerBound..<end.upperBound])
        guard let profile = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
              let entitlements = profile["Entitlements"] as? [String: Any] else { return false }
        let environment = entitlements["aps-environment"] ?? entitlements["com.apple.developer.aps-environment"]
        return environment as? String == "development"
    }

    private static func embeddedProvisioningProfile() -> Data? {
        #if os(iOS)
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else { return nil }
        #else
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/embedded.provisionprofile")
        #endif
        return try? Data(contentsOf: url)
    }
}
