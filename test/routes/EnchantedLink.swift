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

        let response = try await descope.enchantedLink.signUp(with: .email, loginId: "foo", details: nil, redirectURL: nil)
        XCTAssertEqual("link1", response.linkId)
        XCTAssertEqual("pending1", response.pendingRef)
        XCTAssertEqual("a***@b.com", response.maskedEmail)
        XCTAssertNil(response.maskedPhone)
    }

    func testSignUpSMS() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: enchantedLinkPhonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signup/sms")
            let body = (try! JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as! [String: Any]
            XCTAssertEqual(body["loginId"] as? String, "foo")
        }

        let response = try await descope.enchantedLink.signUp(with: .sms, loginId: "foo", details: nil, redirectURL: nil)
        XCTAssertEqual("link1", response.linkId)
        XCTAssertEqual("pending1", response.pendingRef)
        XCTAssertNil(response.maskedEmail)
        XCTAssertEqual("+1******890", response.maskedPhone)
    }

    func testSignUpWhatsAppNotSupported() async throws {
        let descope = DescopeSDK.mock()
        do {
            _ = try await descope.enchantedLink.signUp(with: .whatsapp, loginId: "foo", details: nil, redirectURL: nil)
            XCTFail("Expected an error to be thrown")
        } catch {
            XCTAssertEqual(error, .invalidArguments)
        }
    }

    func testSignInEmail() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: enchantedLinkEmailPayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signin/email")
        }

        let response = try await descope.enchantedLink.signIn(with: .email, loginId: "foo", redirectURL: nil, options: [])
        XCTAssertEqual("a***@b.com", response.maskedEmail)
    }

    func testSignInSMS() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: enchantedLinkPhonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signin/sms")
        }

        let response = try await descope.enchantedLink.signIn(with: .sms, loginId: "foo", redirectURL: nil, options: [])
        XCTAssertEqual("+1******890", response.maskedPhone)
    }

    func testSignUpOrInSMS() async throws {
        let descope = DescopeSDK.mock()

        MockHTTP.push(body: enchantedLinkPhonePayload) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString ?? "", "https://api.descope.com/v1/auth/enchantedlink/signup-in/sms")
        }

        let response = try await descope.enchantedLink.signUpOrIn(with: .sms, loginId: "foo", redirectURL: nil, options: [])
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
