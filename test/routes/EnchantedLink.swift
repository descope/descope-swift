import XCTest
@testable import DescopeKit

class TestEnchantedLink: XCTestCase {
    func testSignUpEmail() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: enchantedLinkEmailPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signup/email")
            let body = (try! JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as! [String: Any]
            XCTAssertEqual(body["loginId"] as? String, "foo")
        }

        let response = try await descope.enchantedLink.signUp(loginId: "foo", details: nil, redirectURL: nil)
        XCTAssertEqual("link1", response.linkId)
        XCTAssertEqual("pending1", response.pendingRef)
        XCTAssertEqual("a***@b.com", response.maskedEmail)
        XCTAssertNil(response.maskedPhone)
    }

    func testSignUpWithPhone() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: enchantedLinkPhonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signup/sms")
            let body = (try! JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as! [String: Any]
            XCTAssertEqual(body["loginId"] as? String, "+10000000000")
        }

        let response = try await descope.enchantedLink.signUpWithPhone("+10000000000", details: nil, redirectURL: nil)
        XCTAssertEqual("link1", response.linkId)
        XCTAssertEqual("pending1", response.pendingRef)
        XCTAssertEqual("", response.maskedEmail)
        XCTAssertEqual("+1******890", response.maskedPhone)
    }

    func testSignInEmail() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: enchantedLinkEmailPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signin/email")
        }

        let response = try await descope.enchantedLink.signIn(loginId: "foo", redirectURL: nil, options: [])
        XCTAssertEqual("a***@b.com", response.maskedEmail)
    }

    func testSignInWithPhone() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: enchantedLinkPhonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signin/sms")
        }

        let response = try await descope.enchantedLink.signInWithPhone("+10000000000", redirectURL: nil, options: [])
        XCTAssertEqual("+1******890", response.maskedPhone)
    }

    func testSignUpOrInWithPhone() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: enchantedLinkPhonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signup-in/sms")
        }

        let response = try await descope.enchantedLink.signUpOrInWithPhone("+10000000000", redirectURL: nil, options: [])
        XCTAssertEqual("+1******890", response.maskedPhone)
    }
}

private let enchantedLinkEmailPayload = """
{
    "linkId": "link1",
    "pendingRef": "pending1",
    "maskedEmail": "a***@b.com"
}
"""

private let enchantedLinkPhonePayload = """
{
    "linkId": "link1",
    "pendingRef": "pending1",
    "maskedPhone": "+1******890"
}
"""
