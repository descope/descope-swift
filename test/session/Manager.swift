import XCTest
@testable import DescopeKit

@MainActor
class TestSessionManager: XCTestCase {
    func testRefreshNotNeeded() async throws {
        let refreshed = try makeRefreshResponse()
        let auth = MockAuth { refreshed }
        let manager = try makeManager(auth: auth, session: makeSession(expiresIn: 600))

        try await manager.refreshSessionIfNeeded()

        XCTAssertEqual(0, auth.calls)
    }

    func testSingleRefresh() async throws {
        let gate = Gate()
        let refreshed = try makeRefreshResponse()
        let auth = MockAuth { await gate.wait(); return refreshed }
        let storage = MockStorage(session: try makeSession(expiresIn: 30))
        let manager = makeManager(auth: auth, storage: storage)
        let delegate = CountingDelegate()
        manager.addDelegate(delegate)

        let callers = (0..<10).map { _ in Task { try await manager.refreshSessionIfNeeded() } }
        await settle()
        gate.open()
        for caller in callers {
            try await caller.value
        }

        XCTAssertEqual(1, auth.calls)
        XCTAssertEqual(1, storage.saves)
        XCTAssertEqual(1, delegate.tokenUpdates)
        XCTAssertEqual(refreshed.sessionToken.jwt, manager.session?.sessionJwt)
    }

    func testSharedFailure() async throws {
        let gate = Gate()
        let auth = MockAuth { () async throws(DescopeError) -> RefreshResponse in await gate.wait(); throw .networkError }
        let manager = try makeManager(auth: auth, session: makeSession(expiresIn: 30))

        let callers = (0..<10).map { _ in Task { () async -> DescopeError? in
            do throws(DescopeError) {
                try await manager.refreshSessionIfNeeded()
                return nil
            } catch {
                return error
            }
        } }
        await settle()
        gate.open()
        var errors: [DescopeError?] = []
        for caller in callers {
            errors.append(await caller.value)
        }

        XCTAssertEqual(1, auth.calls)
        XCTAssertTrue(errors.allSatisfy { $0 == .networkError })
    }

    func testRefreshCompletesWhenCallerCancelled() async throws {
        let gate = Gate()
        let refreshed = try makeRefreshResponse()
        let auth = MockAuth { await gate.wait(); return refreshed }
        let storage = MockStorage(session: try makeSession(expiresIn: 30))
        let manager = makeManager(auth: auth, storage: storage)

        let caller = Task { try await manager.refreshSessionIfNeeded() }
        await settle()
        caller.cancel()
        gate.open()
        try? await caller.value
        await settle()

        XCTAssertEqual(1, storage.saves)
        XCTAssertEqual(refreshed.sessionToken.jwt, manager.session?.sessionJwt)
    }

    func testSessionReplacedDuringSuccess() async throws {
        let gate = Gate()
        let refreshed = try makeRefreshResponse()
        let auth = MockAuth { () async throws(DescopeError) -> RefreshResponse in
            if !gate.isOpen { await gate.wait() }
            return refreshed
        }
        let manager = try makeManager(auth: auth, session: makeSession(expiresIn: 30))

        let first = Task { try await manager.refreshSessionIfNeeded() }
        await settle()
        manager.manageSession(try makeSession(expiresIn: 20))
        gate.open()
        let second = Task { try await manager.refreshSessionIfNeeded() }
        try await first.value
        try await second.value

        XCTAssertEqual(2, auth.calls)
        XCTAssertEqual(refreshed.sessionToken.jwt, manager.session?.sessionJwt)
    }

    func testSessionReplacedDuringFailure() async throws {
        let gate = Gate()
        let refreshed = try makeRefreshResponse()
        let auth = MockAuth { () async throws(DescopeError) -> RefreshResponse in
            if !gate.isOpen {
                await gate.wait()
                throw .networkError
            }
            return refreshed
        }
        let manager = try makeManager(auth: auth, session: makeSession(expiresIn: 30))

        let first = Task { try await manager.refreshSessionIfNeeded() }
        await settle()
        manager.manageSession(try makeSession(expiresIn: 20))
        gate.open()
        let second = Task { try await manager.refreshSessionIfNeeded() }
        try await first.value
        try await second.value

        XCTAssertEqual(2, auth.calls)
    }

    func testKeepsUserUpdatedDuringRefresh() async throws {
        let gate = Gate()
        let refreshed = try makeRefreshResponse()
        let auth = MockAuth { await gate.wait(); return refreshed }
        let manager = try makeManager(auth: auth, session: makeSession(expiresIn: 30))
        var updatedUser = user
        updatedUser.name = "Updated"

        let caller = Task { try await manager.refreshSessionIfNeeded() }
        await settle()
        manager.updateUser(with: updatedUser)
        gate.open()
        try await caller.value

        XCTAssertEqual(refreshed.sessionToken.jwt, manager.session?.sessionJwt)
        XCTAssertEqual(updatedUser, manager.session?.user)
    }

    private func makeManager(auth: MockAuth, session: DescopeSession) -> DescopeSessionManager {
        return makeManager(auth: auth, storage: MockStorage(session: session))
    }

    private func makeManager(auth: MockAuth, storage: MockStorage) -> DescopeSessionManager {
        var config = DescopeConfig()
        config.projectId = "P123"
        let manager = DescopeSessionManager(storage: storage, auth: auth, config: config)
        manager.periodicCheckFrequency = 0
        return manager
    }

    private func settle() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }
}

private func makeJwt(expiresIn: Int) -> String {
    let now = Int(Date().timeIntervalSince1970)
    let header = #"{"alg":"HS256","typ":"JWT"}"#
    let payload = #"{"sub":"user","iss":"https://descope.com/bla/P123","iat":\#(now),"exp":\#(now + expiresIn)}"#
    return [header, payload, "signature"]
        .map { Data($0.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "") }
        .joined(separator: ".")
}

private func makeSession(expiresIn: Int) throws(DescopeError) -> DescopeSession {
    return try DescopeSession(sessionJwt: makeJwt(expiresIn: expiresIn), refreshJwt: makeJwt(expiresIn: 3600), user: user)
}

private func makeRefreshResponse() throws(DescopeError) -> RefreshResponse {
    return RefreshResponse(sessionToken: try Token(jwt: makeJwt(expiresIn: 600)), refreshToken: nil)
}

private let user = DescopeUser(
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
    authentication: DescopeUser.Authentication(passkey: false, password: false, totp: false, oauth: [], sso: false, scim: false),
    authorization: DescopeUser.Authorization(roles: [], ssoAppIds: []),
    customAttributes: [:],
    isUpdateRequired: false,
)

@MainActor
private final class Gate {
    private(set) var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        continuations.forEach { $0.resume() }
        continuations = []
    }
}

@MainActor
private final class MockAuth: DescopeAuth {
    private(set) var calls = 0
    private let refresh: () async throws(DescopeError) -> RefreshResponse

    init(refresh: @escaping () async throws(DescopeError) -> RefreshResponse) {
        self.refresh = refresh
    }

    func refreshSession(refreshJwt: String) async throws(DescopeError) -> RefreshResponse {
        calls += 1
        return try await refresh()
    }

    func me(refreshJwt: String) async throws(DescopeError) -> DescopeUser { throw .networkError }
    func tenants(dct: Bool, tenantIds: [String], refreshJwt: String) async throws(DescopeError) -> [DescopeTenant] { throw .networkError }
    func migrateSession(externalToken: String) async throws(DescopeError) -> AuthenticationResponse { throw .networkError }
    func revokeSessions(_ revoke: RevokeType, refreshJwt: String) async throws(DescopeError) { throw .networkError }
}

private final class MockStorage: DescopeSessionStorage {
    private(set) var saves = 0
    private let session: DescopeSession

    init(session: DescopeSession) {
        self.session = session
    }

    func saveSession(_ session: DescopeSession) { saves += 1 }
    func loadSession() -> DescopeSession? { session }
    func removeSession() {}
}

@MainActor
private final class CountingDelegate: DescopeSessionManagerDelegate {
    private(set) var tokenUpdates = 0

    func sessionManagerDidUpdateTokens(_ sessionManager: DescopeSessionManager, session: DescopeSession) { tokenUpdates += 1 }
    func sessionManagerDidUpdateUser(_ sessionManager: DescopeSessionManager, session: DescopeSession) {}
}
