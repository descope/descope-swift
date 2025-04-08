
import Foundation

/// The configuration of the Descope SDK.
public struct DescopeConfig {
    /// The id of the Descope project.
    public var projectId: String = ""
    
    /// An optional override for the base URL of the Descope server.
    public var baseURL: String?

    /// An optional object to handle logging in the Descope SDK.
    ///
    /// The default value of this property is `nil` and thus logging will be completely
    /// disabled. During development if you encounter any issues you can use either
    /// ``DescopeLogger/debugLogger`` or ``DescopeLogger/unsafeLogger`` to enable
    /// logging and diagnose the problem.
    ///
    /// ```swift
    /// Descope.setup(projectId: "...") { config in
    ///     config.logger = .debugLogger
    /// }
    /// ```
    ///
    /// This will configure a simple logger that prints all logs to the console, but
    /// does not output any potentially unsafe runtime values.
    ///
    /// During development you might want to use ``DescopeLogger/unsafeLogger`` instead.
    /// This will configure a logger that prints all log data, including potentially unsafe
    /// runtime values such as secrets, personal information, network payloads, etc.
    ///
    /// ```swift
    /// Descope.setup(projectId: "...") { config in
    ///     // causes a compilation warning to appear to prevent accidental use
    ///     config.logger = .unsafeLogger
    /// }
    /// ```
    ///
    /// If your application uses some logging framework or third party service you can forward
    /// the Descope SDK log messages to it by subclassing ``DescopeLogger`` and overriding
    /// the `output` method. See the documentation for ``DescopeLogger`` for more details.
    public var logger: DescopeLogger?

    /// An optional object to override how HTTP requests are performed.
    ///
    /// The default value of this property is always `nil`, and the SDK uses its own
    /// internal `URLSession` object to perform HTTP requests.
    ///
    /// This property can be useful to test code that uses the Descope SDK without any
    /// network requests actually taking place. In most other cases there shouldn't be
    /// any need to use it.
    public var networkClient: DescopeNetworkClient?
}

/// Built-in console loggers for use during development.
extension DescopeLogger {
    /// A simple logger that prints all logs to the console, but does not output any
    /// potentially unsafe runtime values.
    public static let debugLogger: DescopeLogger = ConsoleLogger.debug

    /// A simple logger that prints all logs to the console, including potentially unsafe
    /// runtime values such as secrets, personal information, network payloads, etc.
    ///
    /// - Note: This logger is not actually deprecated, but it's marked as such so that the
    ///     Swift compiler shows a warning at build time if this logger is used unintentionally.
    @available(*, deprecated, message: "Do not use unsafeLogger in release builds intended for production")
    public static let unsafeLogger: DescopeLogger = ConsoleLogger.unsafe
}

/// The ``DescopeNetworkClient`` protocol can be used to override how HTTP requests
/// are performed by the SDK when calling the Descope server.
///
/// Your code should implement the ``call(request:)`` method and either return the
/// appropriate HTTP response values or throw an error.
///
/// For example, when testing code that uses the Descope SDK we might want to make
/// sure no network requests are actually made. A simple `DescopeNetworkClient`
/// implementation that always throws an error might look like this:
///
///     class FailingNetworkClient: DescopeNetworkClient {
///         var error: DescopeError = .networkError
///
///         func call(request: URLRequest) async throws -> (Data, URLResponse) {
///             throw error
///         }
///     }
///
/// The method signature is intentionally identical to the `data(for:)` method
/// in `URLSession`, so if for example all we want is for network requests made by
/// the Descope SDK to use the same `URLSession` instance we use elsewhere we can
/// use code such as this:
///
///     let descopeSDK = DescopeSDK(projectId: "...") { config in
///         config.networkClient = AppNetworkClient(session: appSession)
///     }
///
///     // ... elsewhere
///
///     class AppNetworkClient: DescopeNetworkClient {
///         let session: URLSession
///
///         init(_ session: URLSession) {
///             self.session = session
///         }
///
///         func call(request: URLRequest) async throws -> (Data, URLResponse) {
///             return try await session.data(for: request)
///         }
///     }
public protocol DescopeNetworkClient: Sendable {
    /// Loads data using a `URLRequest` and returns the `data` and `response`.
    ///
    /// - Note: The code that calls this function expects the response object to be an
    ///     instance of the `HTTPURLResponse` class and will throw an error if it's not.
    ///     This isn't reflected in the function signature to keep this simple to use
    ///     and aligned with the types in the `data(for:)` method in `URLSession`.
    func call(request: URLRequest) async throws -> (Data, URLResponse)
}
