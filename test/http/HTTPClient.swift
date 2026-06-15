
import XCTest
@testable import DescopeKit

class TestHttpMethods: XCTestCase {
    let client = HTTPClient(baseURL: "http://example", logger: nil, networkClient: MockHTTP.networkClient)
    
    func testGet() async throws {
        MockHTTP.push(json: MockResponse.json, headers: MockResponse.headers) { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.absoluteString, "http://example/route?param=spaced%20value")
            XCTAssertNil(request.httpBody)
            XCTAssertNil(request.httpBodyStream)
        }
        let resp: MockResponse = try await client.get("route", params: ["param": "spaced value"])
        XCTAssertEqual(resp, MockResponse.instance)
    }
    
    func testPost() async throws {
        MockHTTP.push(json: MockResponse.json, headers: MockResponse.headers) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "http://example/route")
            XCTAssertEqual(request.allHTTPHeaderFields?["Content-Length"], String(mockBodyString.count))
            XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
            guard let data = request.httpBody, let body = String(bytes: data, encoding: .utf8) else { return XCTFail("Invalid body") }
            XCTAssertEqual(body, mockBodyString)
        }
        let resp: MockResponse = try await client.post("route", body: mockBodyJSON)
        XCTAssertEqual(resp, MockResponse.instance)
    }
    
    func testCompacting() async throws {
        let params: [String: String?] = [
            "a": "b",
            "c": nil,
        ]
        
        let body: [String: Any?] = [
            "a": "b",
            "c": nil,
            "d": ["e", "f"],
            "g": ["h": nil, "i": [String: Any]()],
        ]

        MockHTTP.push(json: MockResponse.json, headers: MockResponse.headers) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "http://example/route?a=b")
            guard let data = request.httpBody, let json = try? JSONSerialization.jsonObject(with: data) else { return XCTFail("Invalid body") }
            guard let sorted = try? JSONSerialization.data(withJSONObject: json, options: .sortedKeys), let sortedBody = String(bytes: sorted, encoding: .utf8) else { return XCTFail("Conversion failed") }
            XCTAssertEqual(sortedBody, #"{"a":"b","d":["e","f"],"g":{"i":{}}}"#)
        }
        
        let resp: MockResponse = try await client.post("route", params: params, body: body)
        XCTAssertEqual(resp, MockResponse.instance)
    }

    func testbaseURLForProjectId() {
        XCTAssertEqual("https://api.descope.com", baseURLForProjectId(""))
        XCTAssertEqual("https://api.descope.com", baseURLForProjectId("Puse"))
        XCTAssertEqual("https://api.descope.com", baseURLForProjectId("Puse1ar"))
        XCTAssertEqual("https://api.use1.descope.com", baseURLForProjectId("Puse12aAc4T2V93bddihGEx2Ryhc8e5Z"))
        XCTAssertEqual("https://api.use1.descope.com", baseURLForProjectId("Puse12aAc4T2V93bddihGEx2Ryhc8e5Zfoobar"))
    }

    func testFailure() async throws {
        do {
            MockHTTP.push(statusCode: 400, json: [:])
            try await client.get("route")
            XCTFail("No error thrown")
        } catch DescopeError.httpError {
            // ok
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        do {
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
            MockHTTP.push(error: error)
            try await client.get("route")
            XCTFail("No error thrown")
        } catch .networkError {
            // ok
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTraceId() async throws {
        let logger = CapturingLogger()
        let client = HTTPClient(baseURL: "http://example", logger: logger, networkClient: MockHTTP.networkClient)

        // the CF-Ray header is exposed on the error and included in the failure log
        do {
            MockHTTP.push(statusCode: 400, json: [:], headers: ["CF-Ray": "8a1b2c3d4e5f6789-IAD"])
            try await client.get("route")
            XCTFail("No error thrown")
        } catch let err as DescopeError {
            XCTAssertEqual(err.traceId, "8a1b2c3d4e5f6789-IAD")
            XCTAssertTrue(logger.messages.contains { $0.contains("8a1b2c3d4e5f6789-IAD") }, "Expected the CF-Ray to appear in the failure log")
        }

        // no CF-Ray header means no trace identifier
        do {
            MockHTTP.push(statusCode: 400, json: [:])
            try await client.get("route")
            XCTFail("No error thrown")
        } catch let err as DescopeError {
            XCTAssertNil(err.traceId)
        }
    }

    func testTraceIdForErrorResponse() async throws {
        let client = ParsingHTTPClient(baseURL: "http://example", logger: nil, networkClient: MockHTTP.networkClient)
        do {
            MockHTTP.push(statusCode: 400, json: ["errorCode": "E061102", "errorMessage": "failed to validate nonce"], headers: ["CF-Ray": "abc123def456-IAD"])
            try await client.get("route")
            XCTFail("No error thrown")
        } catch let err as DescopeError {
            XCTAssertEqual(err.code, "E061102")
            XCTAssertEqual(err.traceId, "abc123def456-IAD")
        }
    }
}

private final class CapturingLogger: DescopeLogger, @unchecked Sendable {
    nonisolated(unsafe) var messages: [String] = []

    init() {
        super.init(level: .debug, unsafe: false)
    }

    override func output(level: Level, message: String, unsafe values: [Any]) {
        messages.append(message)
    }
}

private final class ParsingHTTPClient: HTTPClient {
    override func errorForResponseData(_ data: Data) -> DescopeError? {
        return DescopeError(errorResponse: data)
    }
}

private let mockBodyJSON: [String: Sendable] = ["foo": 4]
private let mockBodyString = #"{"foo":4}"#

private struct MockResponse: JSONResponse, Equatable {
    var id: Int
    var st: String
    var hd: String?

    static let instance = MockResponse(id: 7, st: "foo", hd: "bar")
    static let json: [String: Sendable] = ["id": instance.id, "st": instance.st]
    static let headers: [String: String] = ["hd": instance.hd!]
    
    mutating func setValues(from data: Data, response: HTTPURLResponse) throws {
        guard let headers = response.allHeaderFields as? [String: String] else { return }
        for (name, value) in headers where name == "hd" {
            hd = value
        }
    }
}
