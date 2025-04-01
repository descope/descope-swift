import Foundation

class SystemInfo {
    #if os(iOS)
    let osName = "iOS"
    let osSysctl = "hw.machine"
    #else
    let osName = "macOS"
    let osSysctl = "hw.model"
    #endif
    
    let osVersion: String
    let appName: String?
    let appVersion: String?
    let device: String?
    
    init() {
        osVersion = SystemInfo.computeOSVersion()
        appName = SystemInfo.computeAppName()
        appVersion = SystemInfo.computeAppVersion()
        device = SystemInfo.computeDevice(osSysctl: osSysctl)
    }
    
    private static func computeOSVersion() -> String {
        let ver = ProcessInfo.processInfo.operatingSystemVersion
        return "\(ver.majorVersion).\(ver.minorVersion).\(ver.patchVersion)"
    }
    
    private static func computeAppName() -> String? {
        if let appName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String {
            return appName
        }
        return nil
    }
    
    private static func computeAppVersion() -> String? {
        if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return appVersion
        }
        return nil
    }
    
    private static func computeDevice(osSysctl: String) -> String? {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        // get the size of the value first
        var size = 0
        guard sysctlbyname(osSysctl, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        
        // create an appropriately sized array and call again to retrieve the value
        var chars = [CChar](repeating: 0, count: size)
        guard sysctlbyname(osSysctl, &chars, &size, nil, 0) == 0 else { return nil }
        
        return String(utf8String: chars)
        #endif
    }
}
