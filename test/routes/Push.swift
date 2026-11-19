
import XCTest
@testable import DescopeKit

class TestPush: XCTestCase {
    func testCIBARequest() throws {
        let descope = DescopeSDK.mock(projectId: "P2abc")
        let session = try makeSession(userId: "U1")

        let request = descope.push.cibaRequest(from: payload(), session: session, allowedHosts: [])
        XCTAssertEqual(request, DescopeCIBARequest(url: URL(string: "https://api.descope.com/login/P2abc?flow=ciba&user_code=ABC")!, userId: "U1", projectId: "P2abc", title: "Acme Travel", body: "Book UA 954"))
    }

    func testCIBARequestRejectsUntrustedPayloads() throws {
        let descope = DescopeSDK.mock(projectId: "P2abc")
        let session = try makeSession(userId: "U1")

        XCTAssertNil(descope.push.cibaRequest(from: payload(category: "other"), session: session, allowedHosts: []))
        XCTAssertNil(descope.push.cibaRequest(from: payload(url: "https://evil.example.com/login/P2abc?flow=ciba"), session: session, allowedHosts: []))
        XCTAssertNil(descope.push.cibaRequest(from: payload(url: "http://api.descope.com/login/P2abc?flow=ciba"), session: session, allowedHosts: []))
        XCTAssertNil(descope.push.cibaRequest(from: payload(url: "https://api.descope.com.evil.example.com/login"), session: session, allowedHosts: []))
        XCTAssertNil(descope.push.cibaRequest(from: payload(url: "https://api.descope.com@evil.example.com/login"), session: session, allowedHosts: []))
        XCTAssertNil(descope.push.cibaRequest(from: payload(url: #"https://evil.example.com\@api.descope.com/login"#), session: session, allowedHosts: []))
        XCTAssertNil(descope.push.cibaRequest(from: payload(projectId: "P2other"), session: session, allowedHosts: []))
        XCTAssertNil(descope.push.cibaRequest(from: payload(userId: "U2"), session: session, allowedHosts: []))
        XCTAssertNil(descope.push.cibaRequest(from: payload(userId: nil), session: session, allowedHosts: []))
    }

    func testCIBARequestAllowedHosts() throws {
        let descope = DescopeSDK.mock(projectId: "P2abc")
        let session = try makeSession(userId: "U1")
        let custom = payload(url: "https://Auth.Example.com/login/P2abc?flow=ciba")

        XCTAssertNil(descope.push.cibaRequest(from: custom, session: session, allowedHosts: []))
        XCTAssertNotNil(descope.push.cibaRequest(from: custom, session: session, allowedHosts: ["auth.example.com"]))
    }

    func testCIBARequestUsesConfiguredBaseURL() throws {
        let descope = DescopeSDK(projectId: "P2abc") { $0.baseURL = "https://localhost:8443" }
        let session = try makeSession(userId: "U1")

        XCTAssertNotNil(descope.push.cibaRequest(from: payload(url: "https://localhost:8443/login/P2abc?flow=ciba"), session: session, allowedHosts: []))
        XCTAssertNil(descope.push.cibaRequest(from: payload(), session: session, allowedHosts: []))
    }

    func testSignInRequest() throws {
        let descope = DescopeSDK.mock(projectId: "P2abc")
        let session = try makeSession(userId: "U1")
        let signIn: (String, String?, String?) -> [AnyHashable: Any] = { category, transactionId, userId in
            var payload: [AnyHashable: Any] = ["aps": ["alert": "You have a new sign-in request", "category": category], "projectId": "P2abc"]
            payload["transactionId"] = transactionId
            payload["userId"] = userId
            return payload
        }

        XCTAssertEqual(descope.push.signInRequest(from: signIn("descope_sign_in", "PT123", "U1"), session: session), DescopePushSignInRequest(transactionId: "PT123", userId: "U1"))
        XCTAssertNil(descope.push.signInRequest(from: signIn("descope_ciba", "PT123", "U1"), session: session))
        XCTAssertNil(descope.push.signInRequest(from: signIn("descope_sign_in", "", "U1"), session: session))
        XCTAssertNil(descope.push.signInRequest(from: signIn("descope_sign_in", nil, "U1"), session: session))
        XCTAssertNil(descope.push.signInRequest(from: signIn("descope_sign_in", "PT123", "U2"), session: session))
        XCTAssertNil(descope.push.signInRequest(from: signIn("descope_sign_in", "PT123", nil), session: session))
        XCTAssertNil(descope.push.cibaRequest(from: signIn("descope_sign_in", "PT123", "U1"), session: session, allowedHosts: []))
    }

    func testEnrollDeviceToken() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(json: [:]) { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/push/update")
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer projId:refresh")
            let body = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            XCTAssertEqual(body["token"] as? String, "00ff1a")
            XCTAssertEqual(body["provider"] as? String, APNsEnvironment.isDevelopment ? "apndev" : "apn")
        }

        try await descope.push.enroll(deviceToken: Data([0x00, 0xff, 0x1a]), refreshJwt: "refresh")
    }

    func testAPNsEnvironmentFromProvisioningProfile() {
        XCTAssertFalse(APNsEnvironment.isDevelopment(provisioningProfile: nil))
        XCTAssertFalse(APNsEnvironment.isDevelopment(provisioningProfile: Data("garbage".utf8)))
        XCTAssertTrue(APNsEnvironment.isDevelopment(provisioningProfile: profile(entitlement: "aps-environment", value: "development")))
        XCTAssertFalse(APNsEnvironment.isDevelopment(provisioningProfile: profile(entitlement: "aps-environment", value: "production")))
        XCTAssertTrue(APNsEnvironment.isDevelopment(provisioningProfile: profile(entitlement: "com.apple.developer.aps-environment", value: "development")))
    }
}

private func payload(category: String = "descope_ciba", url: String = "https://api.descope.com/login/P2abc?flow=ciba&user_code=ABC", projectId: String = "P2abc", userId: String? = "U1") -> [AnyHashable: Any] {
    var payload: [AnyHashable: Any] = [
        "aps": ["alert": ["title": "Acme Travel", "body": "Book UA 954"], "sound": "default", "category": category],
        "url": url,
        "projectId": projectId,
    ]
    payload["userId"] = userId
    return payload
}

/// A stand-in for embedded.mobileprovision: binary CMS bytes around a plain text plist.
private func profile(entitlement: String, value: String) -> Data {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict><key>Entitlements</key><dict><key>\(entitlement)</key><string>\(value)</string></dict></dict></plist>
    """
    return Data([0x30, 0x82, 0x0f, 0x00]) + Data(plist.utf8) + Data([0xa0, 0x82, 0x00])
}

private func makeSession(userId: String) throws(DescopeError) -> DescopeSession {
    let now = Int(Date().timeIntervalSince1970)
    let jwt = [#"{"alg":"HS256","typ":"JWT"}"#, #"{"sub":"\#(userId)","iss":"https://descope.com/bla/P2abc","iat":\#(now),"exp":\#(now + 3600)}"#, "signature"]
        .map { Data($0.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "") }
        .joined(separator: ".")
    let user = DescopeUser(userId: userId, loginIds: ["loginId"], status: .enabled, createdAt: Date(), email: nil, isVerifiedEmail: false, phone: nil, isVerifiedPhone: false, name: nil, givenName: nil, middleName: nil, familyName: nil, picture: nil, authentication: DescopeUser.Authentication(passkey: false, password: false, totp: false, oauth: [], sso: false, scim: false), authorization: DescopeUser.Authorization(roles: [], ssoAppIds: []), customAttributes: [:], isUpdateRequired: false)
    return try DescopeSession(sessionJwt: jwt, refreshJwt: jwt, user: user)
}
