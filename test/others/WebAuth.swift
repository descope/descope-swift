
import XCTest
import AuthenticationServices
@testable import DescopeKit

private let startURL = URL(string: "https://example.com/oauth/start")!
private let redirectURL = URL(string: "descopewebauth://redirect?code=abc")!
private let cancelledError = ASWebAuthenticationSessionError(.canceledLogin)

@MainActor
class TestWebAuth: XCTestCase {
    override func setUp() async throws {
        SessionSwizzler.install()
    }

    override func tearDown() async throws {
        SessionSwizzler.uninstall()
    }

    func testDuplicateCallSuccessThenFailure() async throws {
        let (task, completion) = try await startWebAuth()
        completion.call(redirectURL, nil)
        completion.call(nil, cancelledError)
        try await assertSuccess(task)
    }

    func testDuplicateCallFailureThenSuccess() async throws {
        let (task, completion) = try await startWebAuth()
        completion.call(nil, cancelledError)
        completion.call(redirectURL, nil)
        await assertCancelled(task)
    }

    func testDuplicateCallFromBackgroundThread() async throws {
        let (task, completion) = try await startWebAuth()
        let secondCall = expectation(description: "second call")
        completion.call(redirectURL, nil)
        DispatchQueue.global().async {
            completion.call(nil, cancelledError)
            secondCall.fulfill()
        }
        try await assertSuccess(task)
        await fulfillment(of: [secondCall], timeout: 2)
    }

    func testConcurrentCallsFromManyThreads() async throws {
        for _ in 0..<100 {
            let (task, completion) = try await startWebAuth()
            let allCalls = expectation(description: "all calls")
            DispatchQueue.global().async {
                DispatchQueue.concurrentPerform(iterations: 8) { i in
                    completion.call(i.isMultiple(of: 2) ? redirectURL : nil, i.isMultiple(of: 2) ? nil : cancelledError)
                }
                allCalls.fulfill()
            }
            _ = try? await task.value
            await fulfillment(of: [allCalls], timeout: 2)
        }
    }

    private func startWebAuth() async throws -> (Task<String, Error>, CapturedCompletion) {
        SessionSwizzler.captured = nil
        let task = Task {
            try await WebAuth.performAuthentication(url: startURL, accessSharedUserData: false, logger: nil)
        }
        await Task.yield()
        for _ in 0..<200 {
            if let completion = SessionSwizzler.captured {
                return (task, completion)
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        task.cancel()
        struct SessionNotStarted: Error {}
        throw SessionNotStarted()
    }

    private func assertSuccess(_ task: Task<String, Error>, file: StaticString = #filePath, line: UInt = #line) async throws {
        let code = try await task.value
        XCTAssertEqual(code, "abc", file: file, line: line)
    }

    private func assertCancelled(_ task: Task<String, Error>, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            let code = try await task.value
            XCTFail("Expected cancellation, got code \(code)", file: file, line: line)
        } catch {
            XCTAssertTrue(DescopeError.webAuthCancelled ~= error, "Expected cancellation, got \(error)", file: file, line: line)
        }
    }
}

private final class CapturedCompletion: @unchecked Sendable {
    let handler: ASWebAuthenticationSession.CompletionHandler

    init(_ handler: @escaping ASWebAuthenticationSession.CompletionHandler) {
        self.handler = handler
    }

    func call(_ url: URL?, _ error: Error?) {
        handler(url, error)
    }
}

private enum SessionSwizzler {
    nonisolated(unsafe) static var captured: CapturedCompletion?
    nonisolated(unsafe) static var installed = false

    static func install() {
        guard !installed else { return }
        exchange()
        installed = true
    }

    static func uninstall() {
        guard installed else { return }
        exchange()
        installed = false
    }

    private static func exchange() {
        let cls: AnyClass = ASWebAuthenticationSession.self
        let pairs = [
            (NSSelectorFromString("initWithURL:callbackURLScheme:completionHandler:"), #selector(ASWebAuthenticationSession.init(testingURL:callbackURLScheme:testingCompletionHandler:))),
            (#selector(ASWebAuthenticationSession.start), #selector(ASWebAuthenticationSession.testingStart)),
        ]
        for (original, replacement) in pairs {
            guard let a = class_getInstanceMethod(cls, original), let b = class_getInstanceMethod(cls, replacement) else { preconditionFailure("Missing method to swizzle: \(original)") }
            method_exchangeImplementations(a, b)
        }
    }
}

private extension ASWebAuthenticationSession {
    @objc(initForTestingWithURL:callbackURLScheme:completionHandler:)
    convenience init(testingURL url: URL, callbackURLScheme: String?, testingCompletionHandler: @escaping CompletionHandler) {
        SessionSwizzler.captured = CapturedCompletion(testingCompletionHandler)
        self.init(testingURL: url, callbackURLScheme: callbackURLScheme, testingCompletionHandler: testingCompletionHandler)
    }

    @objc func testingStart() -> Bool {
        return true
    }
}
