
import Foundation

/// The ``DescopeSessionManager`` class is used to manage an authenticated
/// user session for an application.
///
/// The session manager takes care of loading and saving the session as well
/// as ensuring that it's refreshed when needed. For the default instances of
/// the ``DescopeSessionManager`` class this means using the keychain for secure
/// storage of the session and refreshing it a short while before it expires.
///
/// Once the user completes a sign in flow successfully you should set the
/// ``DescopeSession`` object as the active session of the session manager.
///
///     let authResponse = try await Descope.otp.verify(with: .email, loginId: "andy@example.com", code: "123456")
///     let session = DescopeSession(from: authResponse)
///     Descope.sessionManager.manageSession(session)
///
/// The session manager can then be used at any time to ensure the session
/// is valid and to authenticate outgoing requests to your backend with a
/// bearer token authorization header.
///
///     var request = URLRequest(url: url)
///     try await request.setAuthorizationHTTPHeaderField(from: Descope.sessionManager)
///     let (data, response) = try await URLSession.shared.data(for: request)
///
/// If your backend uses a different authorization mechanism you can of course
/// use the session JWT directly instead of the extension function. You can either
/// add another extension function on `URLRequest` such as the one above, or you
/// can do the following.
///
///     try await Descope.sessionManager.refreshSessionIfNeeded()
///     guard let sessionJwt = Descope.sessionManager.session?.sessionJwt else { throw ServerError.unauthorized }
///     request.setValue(sessionJwt, forHTTPHeaderField: "X-Auth-Token")
///
/// When the application is relaunched the ``DescopeSessionManager`` loads any
/// existing session automatically, so you can check straight away if there's
/// an authenticated user.
///
///     func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
///         Descope.setup(projectId: "...")
///         if let session = Descope.sessionManager.session {
///             print("User is logged in: \(session)")
///         }
///         return true
///     }
///
/// When the user wants to sign out of the application we revoke the active
/// session and clear it from the session manager:
///
///     guard let refreshJwt = Descope.sessionManager.session?.refreshJwt else { return }
///     try await Descope.auth.logout(refreshJwt: refreshJwt)
///     Descope.sessionManager.clearSession()
///
/// You can customize how the ``DescopeSessionManager`` behaves by using your own
/// `storage` and `lifecycle` objects. See the documentation for the ``init(storage:lifecycle:)``
/// initializer below for more details.
@MainActor
public class DescopeSessionManager {
    /// The object that handles session storage for this manager.
    private let storage: DescopeSessionStorage
    
    /// The object that handles session lifecycle for this manager.
    private let lifecycle: DescopeSessionLifecycle

    /// The active ``DescopeSession`` managed by this object.
    public var session: DescopeSession? {
        return lifecycle.session
    }

    /// Creates a new ``DescopeSessionManager`` object.
    ///
    /// This initializer can be used to create a ``DescopeSessionManager`` instance
    /// with behaviors that are different from the defaults. You can either extend
    /// or customize the ``SessionStorage`` and ``SessionLifecycle`` concrete classes,
    /// or supply your own implementation of the respective protocols.
    ///
    /// - Parameters:
    ///   - storage: An instance of the ``SessionStorage`` class or some other custom
    ///     implementation of the ``DescopeSessionStorage`` protocol.
    ///   - lifecycle: An instance of the ``SessionLifecycle`` class or some other custom
    ///     implementation of the ``DescopeSessionLifecycle`` protocol.
    public init(storage: DescopeSessionStorage, lifecycle: DescopeSessionLifecycle) {
        self.storage = storage
        self.lifecycle = lifecycle
        self.lifecycle.session = storage.loadSession()
    }
    
    /// Set an active ``DescopeSession`` in this manager.
    ///
    /// You should call this function after a user finishes logging in to the
    /// host application.
    ///
    /// The parameter is set as the value of the ``session`` property and is saved
    /// to the keychain so it can be reloaded on the next application launch or
    /// ``DescopeSessionManager`` instantiation.
    ///
    /// - Important: The default ``DescopeSessionStorage`` only keeps at most
    ///     one session in the keychain for simplicity. If for some reason you
    ///     have multiple ``DescopeSessionManager`` objects then be aware that
    ///     unless they use custom `storage` objects they might overwrite
    ///     each other's saved sessions.
    public func manageSession(_ session: DescopeSession) {
        lifecycle.session = session
        storage.saveSession(session)
    }

    /// Clears any active ``DescopeSession`` from this manager and removes it
    /// from the keychain.
    ///
    /// You should call this function as part of a logout flow in the host application.
    /// The ``session`` property is set to `nil` and the session won't be reloaded in
    /// subsequent application launches.
    ///
    /// - Important: The default ``DescopeSessionStorage`` only keeps at most
    ///     one session in the keychain for simplicity. If for some reason you
    ///     have multiple ``DescopeSessionManager`` objects then be aware that
    ///     unless they use custom `storage` objects they might clear each
    ///     other's saved sessions.
    public func clearSession() {
        lifecycle.session = nil
        storage.removeSession()
    }
    
    /// Ensures that the session is valid and refreshes it if needed.
    ///
    /// The session manager checks whether there's an active ``DescopeSession`` and if
    /// its session JWT expires within the next 60 seconds. If that's the case then
    /// the session is refreshed and saved to the keychain before returning.
    ///
    /// - Note: When using a custom ``DescopeSessionManager`` object the exact behavior
    ///     here depends on the `storage` and `lifecycle` objects.
    public func refreshSessionIfNeeded() async throws {
        try await lifecycle.refreshSessionIfNeeded()
        if let session {
            storage.saveSession(session)
        }
    }
    
    /// Updates the active session's underlying JWTs.
    ///
    /// This function accepts a ``RefreshResponse`` value as a parameter which is returned
    /// by calls to `Descope.auth.refreshSession`. The manager saves the updated session
    /// to the keychain before returning (by default).
    ///
    /// - Important: In most circumstances it's best to use `refreshSessionIfNeeded` and let
    ///     it update the session unless you need to invoke `Descope.auth.refreshSession`
    ///     manually.
    ///
    /// - Note: If the ``DescopeSessionManager`` object was created with a custom `storage`
    ///     object then the exact behavior depends on the specific implementation of the
    ///     ``DescopeSessionStorage`` protocol.
    public func updateTokens(with refreshResponse: RefreshResponse) {
        lifecycle.session?.updateTokens(with: refreshResponse)
        if let session {
            storage.saveSession(session)
        }
    }
    
    /// Updates the active session's user details.
    ///
    /// This function accepts a ``DescopeUser`` value as a parameter which is returned by
    /// calls to `Descope.auth.me`. The manager saves the updated session to the
    /// keychain before returning.
    ///
    ///     let userResponse = try await Descope.auth.me(refreshJwt: session.refreshJwt)
    ///     Descope.sessionManager.updateUser(with: userResponse)
    ///
    /// By default, the manager saves the updated session to the keychain before returning,
    /// but this can be overridden with a custom ``DescopeSessionStorage`` object.
    public func updateUser(with user: DescopeUser) {
        lifecycle.session?.updateUser(with: user)
        if let session {
            storage.saveSession(session)
        }
    }
}
