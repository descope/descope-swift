
import XCTest
@testable import DescopeKit

private let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlN3aWZ0eSBNY0FwcGxlcyIsImlhdCI6MTUxNjIzOTAyMiwiaXNzIjoiaHR0cHM6Ly9kZXNjb3BlLmNvbS9ibGEvUDEyMyIsImV4cCI6MTYwMzE3NjYxNCwicGVybWlzc2lvbnMiOlsiZCIsImUiXSwicm9sZXMiOlsidXNlciJdLCJ0ZW5hbnRzIjp7InRlbmFudCI6eyJwZXJtaXNzaW9ucyI6WyJhIiwiYiIsImMiXSwicm9sZXMiOlsiYWRtaW4iXX19fQ.J5SSpVMgq1Uua4ikezhRkoXkDs1rHgu-ag361TyHlTc"

class TestToken: XCTestCase {
    func testTokenDecoding() throws {
        let token: Token = try Token(jwt: jwt)
        
        // Token Error
        do {
            _ = try Token(jwt: "")
            XCTFail("Expected an error to be thrown")
        } catch {
            // Expected to throw
        }
        
        // Basic Fields
        XCTAssertEqual(jwt, token.jwt)
        XCTAssertEqual("1234567890", token.entityId)
        XCTAssertEqual("P123", token.projectId)
        
        // Expiration
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        XCTAssertEqual("20.10.2020", dateFormatter.string(from: token.expiresAt))
        XCTAssertTrue(token.isExpired)

        // Custom Claims
        XCTAssertEqual(1, token.claims.count)
        XCTAssertEqual("Swifty McApples", token.claims["name"] as! String)
        
        // Authorization
        let permissions = token.permissions(tenant: nil)
        XCTAssertEqual(["d", "e"], permissions)
        let roles = token.roles(tenant: nil)
        XCTAssertEqual(["user"], roles)
        
        // Tenant Authorization
        let tenantPermissions = token.permissions(tenant: "tenant")
        XCTAssertEqual(["a", "b", "c"], tenantPermissions)
        let tenantRoles = token.roles(tenant: "tenant")
        XCTAssertEqual(["admin"], tenantRoles)
        XCTAssertEqual([], token.permissions(tenant: "no-such-tenant"))
    }
}
