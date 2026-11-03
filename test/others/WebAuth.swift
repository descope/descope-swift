import XCTest
@testable import DescopeKit

class TestWebAuth: XCTestCase {
    func testSingleResumerIgnoresRepeatedCalls() async {
        let value: Int = await withCheckedContinuation { continuation in
            let resumer = SingleResumer(continuation)
            XCTAssertTrue(resumer.resume(returning: 1))
            XCTAssertFalse(resumer.resume(returning: 2))
            XCTAssertFalse(resumer.resume(returning: 3))
        }
        XCTAssertEqual(value, 1)
    }

    func testSingleResumerConcurrentCalls() async {
        let value: Int = await withCheckedContinuation { continuation in
            let resumer = SingleResumer(continuation)
            DispatchQueue.concurrentPerform(iterations: 100) { i in
                resumer.resume(returning: i)
            }
        }
        XCTAssertTrue((0..<100).contains(value))
    }
}
