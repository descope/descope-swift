import Foundation
@testable import DescopeKit

extension DescopeSDK {
    static func mock(projectId: String = "projId", sessionCookieName: String? = nil, refreshCookieName: String? = nil) -> DescopeSDK {
        return DescopeSDK(projectId: projectId) { config in
            config.logger = .debugLogger
            config.networkClient = MockHTTP.networkClient
            if let sessionCookieName { config.sessionCookieName = sessionCookieName }
            if let refreshCookieName { config.refreshCookieName = refreshCookieName }
        }
    }
}
