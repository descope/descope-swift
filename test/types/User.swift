import XCTest
@testable import DescopeKit

class TestUser: XCTestCase {
    func testUserEncoding() throws {
        var user = DescopeUser(
            userId: "userId",
            loginIds: ["loginId"],
            status: .enabled,
            createdAt: Date(),
            email: "email",
            isVerifiedEmail: true,
            phone: nil,
            isVerifiedPhone: false,
            name: nil,
            givenName: nil,
            middleName: nil,
            familyName: nil,
            picture: nil,
            authentication: DescopeUser.Authentication(passkey: true, password: false, totp: true, oauth: ["foo"], sso: false, scim: true),
            authorization: DescopeUser.Authorization(roles: ["r1", "r2"], ssoAppIds: ["s1"]),
            customAttributes: ["a": "yes"],
            isUpdateRequired: true,
        )

        let encodedUser = try JSONEncoder().encode(user)
        let decodedUser = try JSONDecoder().decode(DescopeUser.self, from: encodedUser)

        XCTAssertTrue(decodedUser.isVerifiedEmail)
        XCTAssertFalse(decodedUser.isVerifiedPhone)
        guard let aValue = decodedUser.customAttributes["a"] as? String else { return XCTFail("Couldn't get custom attribute value as String") }
        XCTAssertEqual("yes", aValue)

        XCTAssertEqual(user, decodedUser)
        XCTAssertTrue(user == decodedUser)

        user.customAttributes["a"] = TestUser()
        XCTAssertNotEqual(user, decodedUser)
        XCTAssertTrue(user != decodedUser)

        user.customAttributes["a"] = "no"
        XCTAssertNotEqual(user, decodedUser)
        XCTAssertTrue(user != decodedUser)

        user.customAttributes["a"] = "yes"
        XCTAssertEqual(user, decodedUser)
        XCTAssertTrue(user == decodedUser)
    }
    
    func testUserDecoding() throws {
        let json = """
        {
            "userId": "userId",
            "loginIds": ["loginId"],
            "createdAt": 123,
            "name": "name",
            "picture": "https://example.com",
            "email": "email",
            "isVerifiedEmail": true,
            "phone": "",
            "isVerifiedPhone": true,
            "middleName": "middleName",
            "familyName": "familyName",
            "customAttributes": "{\\"a\\": \\"yes\\"}"
        }
        """
        
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let user = try decoder.decode(DescopeUser.self, from: data)

        XCTAssertEqual("userId", user.userId)
        XCTAssertEqual(["loginId"], user.loginIds)
        XCTAssertEqual("name", user.name)
        XCTAssertEqual(URL(string: "https://example.com"), user.picture)
        XCTAssertEqual("email", user.email)
        XCTAssertTrue(user.isVerifiedEmail)
        XCTAssertEqual("", user.phone)
        XCTAssertTrue(user.isVerifiedPhone)
        
        XCTAssertEqual(DescopeUser.Status.enabled, user.status)
        XCTAssertNotNil(user.authentication)
        XCTAssertNotNil(user.authorization)

        guard let aValue = user.customAttributes["a"] as? String else { return XCTFail("Couldn't get custom attribute value as String") }
        XCTAssertEqual("yes", aValue)

        XCTAssertTrue(user.isUpdateRequired)
    }
}
