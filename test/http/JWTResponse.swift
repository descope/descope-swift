
import XCTest
@testable import DescopeKit

class TestJWTResponse: XCTestCase {
    let descope = DescopeSDK.mock()

    func testNoRefreshJWT() async throws {
        MockHTTP.push(body: authPayload)
        do {
            _ = try await descope.otp.verify(with: .email, loginId: "foo", code: "123456")
            XCTFail("Expected failure")
        } catch { /* ok */ }
    }

    func testCookieRefreshJWT() async throws {
        MockHTTP.push(body: authPayload, headers: ["Set-Cookie": cookiePayload])
        let authResponse = try await descope.otp.verify(with: .email, loginId: "foo", code: "123456")
        XCTAssertEqual("bar", authResponse.sessionToken.entityId)
        XCTAssertEqual("qux", authResponse.refreshToken.entityId)
    }

    func testCustomCookieNames() async throws {
        let data = Data(customCookieNamesPayload.utf8)
        let sessionCookie = HTTPCookie(properties: [.name: "FOO", .path: "/", .domain: "example.com", .value: sessionJwt])!
        let refreshCookie = HTTPCookie(properties: [.name: "BAR", .path: "/", .domain: "example.com", .value: refreshJwt])!

        var jwtResponse = try JSONDecoder().decode(DescopeClient.JWTResponse.self, from: data)
        try jwtResponse.setValues(from: data, cookies: [sessionCookie, refreshCookie], refreshCookieName: nil)
        let authResponse: AuthenticationResponse = try jwtResponse.convert()
        XCTAssertEqual("bar", authResponse.sessionToken.entityId)
        XCTAssertEqual("qux", authResponse.refreshToken.entityId)
    }

    func testExternalToken() async throws {
        // with external token
        var data = Data(externalTokenPayload.utf8)
        var jwtResponse = try JSONDecoder().decode(DescopeClient.JWTResponse.self, from: data)
        try jwtResponse.setValues(from: data, cookies: [], refreshCookieName: nil)
        var authResponse: AuthenticationResponse = try jwtResponse.convert()
        XCTAssertEqual("ext-token-value", authResponse.externalToken)

        // no external token
        data = Data(noExternalTokenPayload.utf8)
        jwtResponse = try JSONDecoder().decode(DescopeClient.JWTResponse.self, from: data)
        try jwtResponse.setValues(from: data, cookies: [], refreshCookieName: nil)
        authResponse = try jwtResponse.convert()
        XCTAssertNil(authResponse.externalToken)
    }

    func testFlowOutput() async throws {
        // with flow output
        var data = Data(flowOutputPayload.utf8)
        var jwtResponse = try JSONDecoder().decode(DescopeClient.JWTResponse.self, from: data)
        try jwtResponse.setValues(from: data, cookies: [], refreshCookieName: nil)
        var authResponse: AuthenticationResponse = try jwtResponse.convert()
        XCTAssertEqual("value", authResponse.flowOutput["key"] as? String)
        XCTAssertEqual(3, authResponse.flowOutput["count"] as? Int)

        // survives a Codable round-trip, serialized as a JSON string like customAttributes
        let encoded = try JSONEncoder().encode(authResponse)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        XCTAssertTrue(object?["flowOutput"] is String)
        let decoded = try JSONDecoder().decode(AuthenticationResponse.self, from: encoded)
        XCTAssertEqual("value", decoded.flowOutput["key"] as? String)
        XCTAssertEqual(3, decoded.flowOutput["count"] as? Int)
        XCTAssertEqual(true, (decoded.flowOutput["nested"] as? [String: Any])?["inner"] as? Bool)

        // no flow output
        data = Data(noExternalTokenPayload.utf8)
        jwtResponse = try JSONDecoder().decode(DescopeClient.JWTResponse.self, from: data)
        try jwtResponse.setValues(from: data, cookies: [], refreshCookieName: nil)
        authResponse = try jwtResponse.convert()
        XCTAssertTrue(authResponse.flowOutput.isEmpty)
    }

    func testPageCookie() async throws {
        let data = Data(authPayload.utf8)

        let validCookie = HTTPCookie(properties: [.name: "DSR", .path: "/", .domain: "example.com", .value: refreshJwt])!
        let expiredCookie = HTTPCookie(properties: [.name: "DSR", .path: "/", .domain: "example.com", .value: expiredJwt])!
        let newestCookie = HTTPCookie(properties: [.name: "DSR", .path: "/", .domain: "example.com", .value: newestJwt])!

        // should find a valid refresh jwt for the right project
        var jwtResponse = try JSONDecoder().decode(DescopeClient.JWTResponse.self, from: data)
        try jwtResponse.setValues(from: data, cookies: [validCookie], refreshCookieName: nil)
        var authResponse: AuthenticationResponse = try jwtResponse.convert()
        XCTAssertFalse(authResponse.refreshToken.isExpired)

        // should succeed but return an expired JWT since that's all we've got
        jwtResponse = try JSONDecoder().decode(DescopeClient.JWTResponse.self, from: data)
        try jwtResponse.setValues(from: data, cookies: [expiredCookie], refreshCookieName: nil)
        authResponse = try jwtResponse.convert()
        XCTAssertTrue(authResponse.refreshToken.isExpired)

        // should succeed and find the non-expired JWT (order shouldn't matter)
        for v in [[expiredCookie, validCookie], [validCookie, expiredCookie]] {
            jwtResponse = try JSONDecoder().decode(DescopeClient.JWTResponse.self, from: data)
            try jwtResponse.setValues(from: data, cookies: v, refreshCookieName: nil)
            authResponse = try jwtResponse.convert()
            XCTAssertFalse(authResponse.refreshToken.isExpired)
        }

        // should pick the newest JWT out of all valid ones (order shouldn't matter)
        for v in [[expiredCookie, validCookie, newestCookie], [newestCookie, expiredCookie, validCookie], [validCookie, expiredCookie, newestCookie]] {
            jwtResponse = try JSONDecoder().decode(DescopeClient.JWTResponse.self, from: data)
            try jwtResponse.setValues(from: data, cookies: v, refreshCookieName: nil)
            authResponse = try jwtResponse.convert()
            XCTAssertFalse(authResponse.refreshToken.isExpired)
            XCTAssertEqual(authResponse.refreshToken.issuedAt, Date(timeIntervalSince1970: 1526239022))
        }
    }
}

private let cookiePayload = "DSR=\(refreshJwt); Path=/; Expires=Thu, 02 Jan 2025 10:01:41 GMT; Max-Age=2419199; HttpOnly; Secure; SameSite=None"

private let customCookieNamesPayload = """
{
    "sessionJwt": "",
    "refreshJwt": "",
    "sessionCookieName": "FOO",
    "cookieName": "BAR",
    "user": \(userPayload),
    "firstSeen": false
}
"""

private let authPayload = """
{
    "sessionJwt": "\(sessionJwt)",
    "refreshJwt": "",
    "user": \(userPayload),
    "firstSeen": true
}
"""

private let externalTokenPayload = """
{
    "sessionJwt": "\(sessionJwt)",
    "refreshJwt": "\(refreshJwt)",
    "user": \(userPayload),
    "firstSeen": true,
    "externalToken": "ext-token-value"
}
"""

private let flowOutputPayload = """
{
    "sessionJwt": "\(sessionJwt)",
    "refreshJwt": "\(refreshJwt)",
    "user": \(userPayload),
    "firstSeen": true,
    "flowOutput": {
        "key": "value",
        "count": 3,
        "nested": { "inner": true }
    }
}
"""

private let noExternalTokenPayload = """
{
    "sessionJwt": "\(sessionJwt)",
    "refreshJwt": "\(refreshJwt)",
    "user": \(userPayload),
    "firstSeen": true
}
"""

private let userPayload = """
{
    "userId": "userId",
    "loginIds": ["foo"],
    "status": "enabled",
    "email": "email",
    "verifiedEmail": true,
    "createdTime": 123,
    "roleNames": ["r1"],
    "ssoAppIds": ["s1","s2"],
    "webauthn": false,
    "password": true,
    "TOTP": false,
    "OAuth": {"google": true},
    "SAML": true,
    "SCIM": false,
    "customAttributes": {}
}
"""

private let sessionJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiYXIiLCJuYW1lIjoiU3dpZnR5IE1jQXBwbGVzIiwiaWF0IjoxNTE2MjM5MDIyLCJpc3MiOiJmb28iLCJleHAiOjE2MDMxNzY2MTQsInBlcm1pc3Npb25zIjpbImQiLCJlIl0sInJvbGVzIjpbInVzZXIiXSwidGVuYW50cyI6eyJ0ZW5hbnQiOnsicGVybWlzc2lvbnMiOlsiYSIsImIiLCJjIl0sInJvbGVzIjpbImFkbWluIl19fX0.LEcNdzkdOXlzxcVNhvlqOIoNwzgYYfcDv1_vzF3awF8"
private let refreshJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJxdXgiLCJuYW1lIjoiU3dpZnR5IE1jQXBwbGVzIiwiaWF0IjoxNTE2MjM5MDIyLCJpc3MiOiJodHRwczovL2FwaS5kZXNjb3BlLmNvbS9mb28iLCJleHAiOjIxMDMxNzY2MTQsInBlcm1pc3Npb25zIjpbImQiLCJlIl0sInJvbGVzIjpbInVzZXIiXSwidGVuYW50cyI6eyJ0ZW5hbnQiOnsicGVybWlzc2lvbnMiOlsiYSIsImIiLCJjIl0sInJvbGVzIjpbImFkbWluIl19fX0.ow2MV3WwUDeb8PyuJLEFlFiqHhPhvuPTL9O2gRFLMGE"
private let expiredJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJxdXgiLCJuYW1lIjoiU3dpZnR5IE1jQXBwbGVzIiwiaWF0IjoxNTE2MjM5MDIyLCJpc3MiOiJmb28iLCJleHAiOjE1MjMxNzY2MTQsInBlcm1pc3Npb25zIjpbImQiLCJlIl0sInJvbGVzIjpbInVzZXIiXSwidGVuYW50cyI6eyJ0ZW5hbnQiOnsicGVybWlzc2lvbnMiOlsiYSIsImIiLCJjIl0sInJvbGVzIjpbImFkbWluIl19fX0.ICHASqOp7uDiknXu6eINSKLMnixND3-OIAww9ZCN7qs"
private let newestJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJxdXgiLCJuYW1lIjoiU3dpZnR5IE1jQXBwbGVzIiwiaWF0IjoxNTI2MjM5MDIyLCJpc3MiOiJmb28iLCJleHAiOjIxMDMxNzY2MTQsInBlcm1pc3Npb25zIjpbImQiLCJlIl0sInJvbGVzIjpbInVzZXIiXSwidGVuYW50cyI6eyJ0ZW5hbnQiOnsicGVybWlzc2lvbnMiOlsiYSIsImIiLCJjIl0sInJvbGVzIjpbImFkbWluIl19fX0.rgnEi7rxuGEAFiWUrZnyXJvWX8giNQpiBBVVtMwHLZo"
