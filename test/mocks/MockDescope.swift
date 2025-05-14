import Foundation
@testable import DescopeKit

extension DescopeSDK {
    static func mock(projectId: String = "projId") -> DescopeSDK {
        return DescopeSDK(projectId: projectId) { config in
            config.logger = .debugLogger
            config.networkClient = MockHTTP.networkClient
        }
    }
}
