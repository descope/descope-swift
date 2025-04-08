import XCTest
@testable import DescopeKit

class TestAuth: XCTestCase {
    func testMe() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: userPayload) { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer projId:jwt")
            XCTAssertEqual(request.allHTTPHeaderFields?["x-descope-platform-name"], "macos")
            XCTAssertTrue(request.allHTTPHeaderFields?["x-descope-platform-version"]?.contains(".") == true)
            XCTAssertEqual(request.allHTTPHeaderFields?["x-descope-app-name"], "xctest")
            XCTAssertTrue(request.allHTTPHeaderFields?["x-descope-app-version"]?.contains(".") == true)
            XCTAssertTrue(request.allHTTPHeaderFields?["x-descope-device"]?.contains("Mac") == true)
        }
        let user = try await descope.auth.me(refreshJwt: "jwt")

        try checkUser(user)
    }

    func testTenants() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: tenantsPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/me/tenants")
            let body = (try! JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as! [String: Any]
            XCTAssertEqual(body.count, 2)
            XCTAssertEqual(body["dct"] as? Bool, true)
            XCTAssertEqual(body["ids"] as? [String], ["foo", "bar"])
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer projId:jwt")
        }

        let tenants = try await descope.auth.tenants(dct: true, tenantIds: ["foo", "bar"], refreshJwt: "jwt")
        XCTAssertEqual(tenants.count, 1)
        XCTAssertEqual(tenants[0].tenantId, "foo")
        XCTAssertEqual(tenants[0].name, "Foo")
        try checkCustomAttributes(tenants[0].customAttributes)
    }

    func testAuth() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: authPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/otp/verify/email")
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer projId")
        }

        let authResponse = try await descope.otp.verify(with: .email, loginId: "foo", code: "123456")
        XCTAssertEqual("bar", authResponse.sessionToken.entityId)
        XCTAssertEqual("qux", authResponse.refreshToken.entityId)
        XCTAssertTrue(authResponse.isFirstAuthentication)

        try checkUser(authResponse.user)
    }

    func testRefresh() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: authNoRefreshPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/refresh")
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer projId:foo")
        }

        let refreshResponse = try await descope.auth.refreshSession(refreshJwt: "foo")
        XCTAssertEqual("bar", refreshResponse.sessionToken.entityId)
        XCTAssertNil(refreshResponse.refreshToken)
    }

    func checkUser(_ user: DescopeUser) throws {
        XCTAssertEqual("userId", user.userId)
        XCTAssertFalse(user.isVerifiedPhone)
        XCTAssertTrue(user.isVerifiedEmail)
        XCTAssertNil(user.givenName)

        try checkCustomAttributes(user.customAttributes)
    }

    func checkCustomAttributes(_ dict: [String: Any]) throws {
        try checkDictionary(dict)

        guard let array = dict["unnecessaryArray"] as? [Any] else { return XCTFail() }
        try checkArray(array)

        guard let dict = array[3] as? [String: Any] else { return XCTFail() }
        try checkDictionary(dict)
    }

    func checkDictionary(_ dict: [String: Any]) throws {
        XCTAssertEqual("yes", dict["a"] as? String)
        XCTAssertEqual(true, dict["b"] as? Bool)
        XCTAssertEqual(1, dict["c"] as? Int)
    }

    func checkArray(_ array: [Any]) throws {
        XCTAssertEqual("yes", array[0] as? String)
        XCTAssertEqual(true, array[1] as? Bool)
        XCTAssertEqual(1, array[2] as? Int)
    }
}

private let authPayload = """
{
    "sessionJwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiYXIiLCJuYW1lIjoiU3dpZnR5IE1jQXBwbGVzIiwiaWF0IjoxNTE2MjM5MDIyLCJpc3MiOiJmb28iLCJleHAiOjE2MDMxNzY2MTQsInBlcm1pc3Npb25zIjpbImQiLCJlIl0sInJvbGVzIjpbInVzZXIiXSwidGVuYW50cyI6eyJ0ZW5hbnQiOnsicGVybWlzc2lvbnMiOlsiYSIsImIiLCJjIl0sInJvbGVzIjpbImFkbWluIl19fX0.LEcNdzkdOXlzxcVNhvlqOIoNwzgYYfcDv1_vzF3awF8",
    "refreshJwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJxdXgiLCJuYW1lIjoiU3dpZnR5IE1jQXBwbGVzIiwiaWF0IjoxNTE2MjM5MDIyLCJpc3MiOiJmb28iLCJleHAiOjE2MDMxNzY2MTQsInBlcm1pc3Npb25zIjpbImQiLCJlIl0sInJvbGVzIjpbInVzZXIiXSwidGVuYW50cyI6eyJ0ZW5hbnQiOnsicGVybWlzc2lvbnMiOlsiYSIsImIiLCJjIl0sInJvbGVzIjpbImFkbWluIl19fX0.kgsfovgtFXwlr7Ev6XZ_BFMBSFNgTraw_G9WqAj78AA",
    "user": \(userPayload),
    "firstSeen": true
}
"""

private let authNoRefreshPayload = """
{
    "sessionJwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiYXIiLCJuYW1lIjoiU3dpZnR5IE1jQXBwbGVzIiwiaWF0IjoxNTE2MjM5MDIyLCJpc3MiOiJmb28iLCJleHAiOjE2MDMxNzY2MTQsInBlcm1pc3Npb25zIjpbImQiLCJlIl0sInJvbGVzIjpbInVzZXIiXSwidGVuYW50cyI6eyJ0ZW5hbnQiOnsicGVybWlzc2lvbnMiOlsiYSIsImIiLCJjIl0sInJvbGVzIjpbImFkbWluIl19fX0.LEcNdzkdOXlzxcVNhvlqOIoNwzgYYfcDv1_vzF3awF8",
    "refreshJwt": "",
    "user": \(userPayload),
    "firstSeen": false
}
"""

private let tenantsPayload = """
{
    "tenants": [
        {
            "id": "foo",
            "name": "Foo",
            "customAttributes": \(attributesPayload)
        }
    ]
}
"""

private let userPayload = """
{
    "userId": "userId",
    "loginIds": ["loginId"],
    "name": "name",
    "picture": "picture",
    "email": "email",
    "verifiedEmail": true,
    "phone": "phone",
    "createdTime": 123,
    "middleName": "middleName",
    "familyName": "familyName",
    "customAttributes": \(attributesPayload)
}
"""

private let attributesPayload = """
{
    "a": "yes",
    "b": true,
    "c": 1,
    "d": null,
    "unnecessaryArray": [
        "yes",
        true,
        1,
        {
            "a": "yes",
            "b": true,
            "c": 1,
        }
    ]
}
"""
