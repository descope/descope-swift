
import Foundation

class HTTPClient {
    let baseURL: String
    let logger: DescopeLogger?
    let networkClient: DescopeNetworkClient

    init(baseURL: String, logger: DescopeLogger?, networkClient: DescopeNetworkClient?, certificatePins: [String: [String]]? = nil) {
        self.baseURL = baseURL
        self.logger = logger
        self.networkClient = networkClient ?? DefaultNetworkClient(certificatePins: certificatePins, logger: logger)
    }
    
    // Convenience response functions

    final func get<T: JSONResponse>(_ route: String, headers: [String: String] = [:], params: [String: String?] = [:]) async throws(DescopeError) -> T {
        let (data, response) = try await get(route, headers: headers, params: params)
        return try decodeJSON(data: data, response: response)
    }
    
    final func post<T: JSONResponse>(_ route: String, headers: [String: String] = [:], params: [String: String?] = [:], body: [String: Any?] = [:]) async throws(DescopeError) -> T {
        let (data, response) = try await post(route, headers: headers, params: params, body: body)
        return try decodeJSON(data: data, response: response)
    }
    
    // Convenience data functions
    
    @discardableResult
    final func get(_ route: String, headers: [String: String] = [:], params: [String: String?] = [:]) async throws(DescopeError) -> (Data, HTTPURLResponse) {
        return try await call(route, method: "GET", headers: headers, params: params, body: nil)
    }
    
    @discardableResult
    final func post(_ route: String, headers: [String: String] = [:], params: [String: String?] = [:], body: [String: Any?] = [:]) async throws(DescopeError) -> (Data, HTTPURLResponse) {
        return try await call(route, method: "POST", headers: headers, params: params, body: encodeJSON(body))
    }
    
    // Override points
    
    var basePath: String {
        return "/"
    }
    
    var defaultHeaders: [String: String] {
        return [:]
    }
    
    var defaultTimeout: TimeInterval {
        return 15
    }
    
    func errorForResponseData(_ data: Data) -> DescopeError? {
        return nil
    }
    
    // Private
    
    private func call(_ route: String, method: String, headers: [String: String], params: [String: String?], body: Data?) async throws(DescopeError) -> (Data, HTTPURLResponse) {
        let request = try makeRequest(route: route, method: method, headers: headers, params: params, body: body)
        if logger.isUnsafeEnabled {
            logger.info("Starting network call", request.url)
            if let body = request.httpBody, let requestBody = String(bytes: body, encoding: .utf8) {
                logger.debug("Sending request body", requestBody)
            }
        } else {
            logger.info("Starting network call to \(route)")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await networkClient.call(request: request)
        } catch {
            if logger.isUnsafeEnabled {
                logger.error("Network call failed with network error", request.url, error)
            } else {
                logger.error("Network call to \(route) failed with \((error as NSError).code) network error")
            }
            throw DescopeError.networkError.with(cause: error)
        }

        guard let response = response as? HTTPURLResponse else { throw DescopeError(httpError: .invalidResponse) }
        if logger.isUnsafeEnabled, let responseBody = String(bytes: data, encoding: .utf8) {
            logger.debug("Received response body", responseBody)
        }

        if let error = DescopeError(httpStatusCode: response.statusCode) {
            if let responseError = errorForResponseData(data) {
                if logger.isUnsafeEnabled {
                    logger.error("Network call failed with server error", request.url, responseError)
                } else {
                    logger.error("Network call to \(route) failed with \(responseError.code) server error")
                }
                throw responseError
            }
            if logger.isUnsafeEnabled {
                logger.error("Network call failed with \(response.statusCode) http error", request.url, error)
            } else {
                logger.error("Network call to \(route) failed with \(response.statusCode) http error")
            }
            throw error
        }
        
        if logger.isUnsafeEnabled {
            logger.info("Network call finished", request.url)
        } else {
            logger.info("Network call to \(route) finished")
        }

        return (data, response)
    }
    
    private func makeRequest(route: String, method: String, headers: [String: String], params: [String: String?], body: Data?) throws(DescopeError) -> URLRequest {
        let url = try makeURL(route: route, params: params)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: defaultTimeout)
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in mergeHeaders(headers, with: defaultHeaders, for: request) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
    
    private func makeURL(route: String, params: [String: String?]) throws(DescopeError) -> URL {
        guard var url = URL(string: baseURL) else { throw DescopeError(httpError: .invalidRoute) }
        url.appendPathComponent(basePath, isDirectory: false)
        url.appendPathComponent(route, isDirectory: false)
        guard var components = URLComponents(string: url.absoluteString) else { throw DescopeError(httpError: .invalidRoute) }
        if case let params = params.compacted(), !params.isEmpty {
            components.queryItems = params.map(URLQueryItem.init)
        }
        guard let url = components.url else { throw DescopeError(httpError: .invalidRoute) }
        return url
    }
}

// JSON Response

protocol JSONResponse: Decodable {
    mutating func setValues(from data: Data, response: HTTPURLResponse) throws
}

extension JSONResponse {
    mutating func setValues(from data: Data, response: HTTPURLResponse) throws {
        // nothing by default
    }
}

private func decodeJSON<T: JSONResponse>(data: Data, response: HTTPURLResponse) throws(DescopeError) -> T {
    do {
        var val = try JSONDecoder().decode(T.self, from: data)
        try val.setValues(from: data, response: response)
        return val
    } catch {
        throw DescopeError.decodeError.with(cause: error)
    }
}

// JSON Request

private func encodeJSON(_ body: [String: Any?]) throws(DescopeError) -> Data {
    do {
        let compact = body.compacted()
        let data = try JSONSerialization.data(withJSONObject: compact, options: [])
        return data
    } catch {
        throw DescopeError.encodeError.with(cause: error)
    }
}

private extension Dictionary {
    func compacted<T>() -> Dictionary<Key, T> where Value == T? {
        return compactMapValues { value in
            if let dict = value as? Self {
                return dict.compacted() as? T
            }
            return value
        }
    }
}

// HTTP Headers

private func mergeHeaders(_ headers: [String: String], with defaults: [String: String], for request: URLRequest) -> [String: String] {
    var result = request.allHTTPHeaderFields ?? [:]
    if request.httpBody != nil {
        result["Content-Type"] = "application/json"
    }
    result.merge(defaults, uniquingKeysWith: { $1 })
    result.merge(headers, uniquingKeysWith: { $1 })
    return result
}

// Network

private final class DefaultNetworkClient: DescopeNetworkClient {
    private let session: URLSession

    init(certificatePins: [String: [String]]?, logger: DescopeLogger?) {
        self.session = makeURLSession(certificatePins: certificatePins, logger: logger)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    func call(request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}

private func makeURLSession(certificatePins: [String: [String]]?, logger: DescopeLogger?) -> URLSession {
    let configuration = URLSessionConfiguration.default

    #if DEBUG
    // ⚠️ SECURITY WARNING: DEBUG builds disable ALL TLS certificate validation
    // This delegate accepts any certificate, including self-signed and invalid certificates.
    //
    // WHY THIS EXISTS:
    // - Allows testing against local development servers with self-signed certificates
    // - Enables proxy debugging tools (Charles, Proxyman) during development
    //
    // CRITICAL SECURITY REQUIREMENTS:
    // - NEVER ship production builds with DEBUG flags enabled
    // - Verify release builds in Xcode: Build Settings → Swift Compiler → Active Compilation Conditions
    // - Consider using certificate pinning for production (see DescopeConfig.certificatePins)
    // - Add CI/CD checks to prevent DEBUG builds from reaching production
    //
    // If you see this warning in production logs, IMMEDIATELY investigate your build configuration!
    print("⚠️ [DESCOPE SECURITY WARNING] TLS certificate validation is DISABLED in DEBUG mode")
    print("⚠️ This build is vulnerable to man-in-the-middle attacks - DO NOT USE IN PRODUCTION")

    // Note: Certificate pinning is disabled in DEBUG mode to allow development debugging
    return URLSession(configuration: configuration, delegate: CertificateDebugDelegate(), delegateQueue: nil)
    #else
    // Production builds: Use certificate pinning if configured
    if let pins = certificatePins, !pins.isEmpty {
        logger?.info("Certificate pinning enabled for \(pins.keys.count) host(s)")
        return URLSession(configuration: configuration, delegate: CertificatePinningDelegate(pins: pins, logger: logger), delegateQueue: nil)
    } else {
        // No pinning configured - use default system validation
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }
    #endif
}

#if DEBUG
/// **⚠️ SECURITY WARNING: This delegate disables ALL TLS certificate validation**
///
/// This class accepts any certificate without validation, making the connection
/// vulnerable to man-in-the-middle (MITM) attacks.
///
/// - Important: This is ONLY active in DEBUG builds. Production builds MUST NOT
///   include DEBUG compilation flags.
///
/// - Note: If you need to test with specific certificates in development, consider
///   implementing proper certificate pinning instead of disabling all validation.
private final class CertificateDebugDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let trust = challenge.protectionSpace.serverTrust else { return (.performDefaultHandling, nil) }

        // Log every bypassed certificate check
        print("⚠️ [DEBUG] Bypassing certificate validation for: \(challenge.protectionSpace.host)")

        return (.useCredential, URLCredential(trust: trust))
    }
}
#endif
