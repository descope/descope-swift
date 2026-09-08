import XCTest
@testable import DescopeKit

private let emailPayload = """
{
    "linkId": "link1",
    "pendingRef": "pending1",
    "maskedEmail": "a***@b.com"
}
"""

private let phonePayload = """
{
    "linkId": "link2",
    "pendingRef": "pending2",
    "maskedPhone": "+1******890"
}
"""

private func decodeBody(_ request: URLRequest) -> [String: Any] {
    return (try! JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as! [String: Any]
}

class TestEnchantedLink: XCTestCase {
    func testSignUp() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: emailPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signup/email")
            let body = decodeBody(request)
            XCTAssertEqual(body["loginId"] as? String, "foo@bar.com")
            XCTAssertEqual(body["redirectUrl"] as? String, "https://example.com")
            XCTAssertEqual((body["user"] as? [String: Any])?["name"] as? String, "Swifty")
            XCTAssertNil(body["phone"])
        }

        let response = try await descope.enchantedLink.signUp(loginId: "foo@bar.com", details: SignUpDetails(name: "Swifty"), redirectURL: "https://example.com")
        XCTAssertEqual("link1", response.linkId)
        XCTAssertEqual("pending1", response.pendingRef)
        XCTAssertEqual("a***@b.com", response.maskedEmail)
    }

    func testSignUpWithPhone() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: phonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signup/sms")
            let body = decodeBody(request)
            XCTAssertEqual(body["loginId"] as? String, "+15551234567")
            XCTAssertEqual(body["redirectUrl"] as? String, "https://example.com")
            XCTAssertEqual((body["user"] as? [String: Any])?["name"] as? String, "Swifty")
            XCTAssertNil(body["phone"])
        }

        let response = try await descope.enchantedLink.signUpWithPhone("+15551234567", details: SignUpDetails(name: "Swifty"), redirectURL: "https://example.com")
        XCTAssertEqual("link2", response.linkId)
        XCTAssertEqual("pending2", response.pendingRef)
        XCTAssertEqual("+1******890", response.maskedPhone)
    }

    func testSignIn() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: emailPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signin/email")
            let body = decodeBody(request)
            XCTAssertEqual(body["loginId"] as? String, "foo@bar.com")
            XCTAssertNil(body["redirectUrl"])
        }

        let response = try await descope.enchantedLink.signIn(loginId: "foo@bar.com", redirectURL: nil, options: [])
        XCTAssertEqual("a***@b.com", response.maskedEmail)
    }

    func testSignInWithPhone() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: phonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signin/sms")
            let body = decodeBody(request)
            XCTAssertEqual(body["loginId"] as? String, "+15551234567")
            XCTAssertEqual(body["redirectUrl"] as? String, "https://example.com")
        }

        let response = try await descope.enchantedLink.signInWithPhone("+15551234567", redirectURL: "https://example.com", options: [])
        XCTAssertEqual("link2", response.linkId)
        XCTAssertEqual("+1******890", response.maskedPhone)
    }

    func testSignUpOrIn() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: emailPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signup-in/email")
            XCTAssertEqual(decodeBody(request)["loginId"] as? String, "foo@bar.com")
        }

        let response = try await descope.enchantedLink.signUpOrIn(loginId: "foo@bar.com", redirectURL: nil, options: [])
        XCTAssertEqual("a***@b.com", response.maskedEmail)
    }

    func testSignUpOrInWithPhone() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: phonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signup-in/sms")
            let body = decodeBody(request)
            XCTAssertEqual(body["loginId"] as? String, "+15551234567")
            XCTAssertEqual(body["redirectUrl"] as? String, "https://example.com")
        }

        let response = try await descope.enchantedLink.signUpOrInWithPhone("+15551234567", redirectURL: "https://example.com", options: [])
        XCTAssertEqual("link2", response.linkId)
        XCTAssertEqual("+1******890", response.maskedPhone)
    }

    func testUpdateEmail() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: emailPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/update/email")
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer projId:jwt")
            let body = decodeBody(request)
            XCTAssertEqual(body["loginId"] as? String, "foo")
            XCTAssertEqual(body["email"] as? String, "foo@bar.com")
            XCTAssertEqual(body["addToLoginIDs"] as? Bool, true)
            XCTAssertEqual(body["onMergeUseExisting"] as? Bool, false)
        }

        let response = try await descope.enchantedLink.updateEmail("foo@bar.com", loginId: "foo", redirectURL: nil, refreshJwt: "jwt", options: .addToLoginIds)
        XCTAssertEqual("a***@b.com", response.maskedEmail)
    }

    func testUpdatePhone() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: phonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/update/phone/sms")
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer projId:jwt")
            let body = decodeBody(request)
            XCTAssertEqual(body["loginId"] as? String, "foo")
            XCTAssertEqual(body["phone"] as? String, "+15551234567")
            XCTAssertEqual(body["redirectUrl"] as? String, "https://example.com")
            XCTAssertEqual(body["addToLoginIDs"] as? Bool, true)
            XCTAssertEqual(body["onMergeUseExisting"] as? Bool, true)
        }

        let response = try await descope.enchantedLink.updatePhone("+15551234567", loginId: "foo", redirectURL: "https://example.com", refreshJwt: "jwt", options: [.addToLoginIds, .onMergeUseExisting])
        XCTAssertEqual("link2", response.linkId)
        XCTAssertEqual("pending2", response.pendingRef)
        XCTAssertEqual("+1******890", response.maskedPhone)
    }
}
