
import Foundation
#if os(iOS)
import UIKit
#endif

/// Validates device security status
class SecurityValidator {
    private let logger: DescopeLogger?

    init(logger: DescopeLogger?) {
        self.logger = logger
    }

    /// Performs comprehensive security validation
    /// - Parameter mode: How to handle validation failures
    /// - Returns: Result indicating if device is secure
    func validate(mode: SecurityValidationMode) -> Result<Void, SecurityValidationError> {
        var findings: [String] = []

        // Check for jailbreak/root
        if isJailbroken() {
            findings.append("Device appears to be jailbroken/rooted")
        }

        // Check for debugger
        if isDebuggerAttached() {
            findings.append("Debugger is attached")
        }

        // Check for suspicious runtime modifications
        if hasSuspiciousRuntimeModifications() {
            findings.append("Suspicious runtime modifications detected")
        }

        // Handle findings based on mode
        if !findings.isEmpty {
            let message = findings.joined(separator: "; ")

            switch mode {
            case .warn:
                logger?.error("⚠️ [SECURITY] Device security concerns detected: \(message)")
                logger?.error("⚠️ Continuing in WARN mode - configure securityValidationMode to .strict to block operations")
                return .success(())

            case .strict:
                logger?.error("❌ [SECURITY] Device security validation failed: \(message)")
                return .failure(SecurityValidationError(findings: findings))
            }
        }

        logger?.debug("✅ Device security validation passed")
        return .success(())
    }

    // MARK: - Jailbreak Detection

    private func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        // Simulators are not jailbroken
        return false
        #else

        // Check 1: Common jailbreak file paths
        if checkJailbreakFiles() {
            return true
        }

        // Check 2: Can write to system directories
        if canWriteToSystemDirectories() {
            return true
        }

        // Check 3: Suspicious apps installed (Cydia, Sileo, etc.)
        if hasSuspiciousApps() {
            return true
        }

        // Check 4: Dyld environment check
        if hasSuspiciousDyldEnvironment() {
            return true
        }

        // Check 5: Fork() sandbox check
        if canFork() {
            return true
        }

        return false
        #endif
    }

    private func checkJailbreakFiles() -> Bool {
        let suspiciousPaths = [
            // Jailbreak tools
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/Installer.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/sbin/sshd",
            "/usr/bin/sshd",
            "/usr/libexec/sftp-server",
            "/usr/bin/ssh",

            // Package managers
            "/bin/bash",
            "/bin/sh",
            "/etc/apt",
            "/etc/ssh/sshd_config",

            // Common jailbreak files
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/var/lib/cydia",
            "/var/cache/apt",
            "/var/log/syslog",

            // Substrate
            "/Library/MobileSubstrate/DynamicLibraries",
        ]

        for path in suspiciousPaths {
            if FileManager.default.fileExists(atPath: path) {
                logger?.debug("Jailbreak indicator found: \(path)")
                return true
            }

            // Also check if we can open the file (some jailbreaks hide file existence)
            if let file = fopen(path, "r") {
                fclose(file)
                logger?.debug("Jailbreak indicator accessible: \(path)")
                return true
            }
        }

        return false
    }

    private func canWriteToSystemDirectories() -> Bool {
        let testPath = "/private/jailbreak_test_\(UUID().uuidString).txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            logger?.debug("Can write to system directories - likely jailbroken")
            return true
        } catch {
            // Expected - cannot write to system directories
            return false
        }
    }

    private func hasSuspiciousApps() -> Bool {
        #if os(iOS)
        let suspiciousSchemes = [
            "cydia://",
            "sileo://",
            "zbra://",
            "filza://",
            "activator://",
        ]

        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                logger?.debug("Suspicious app scheme detected: \(scheme)")
                return true
            }
        }
        #endif

        return false
    }

    private func hasSuspiciousDyldEnvironment() -> Bool {
        // Check for DYLD_INSERT_LIBRARIES which is commonly used by jailbreak tweaks
        if let libraries = getenv("DYLD_INSERT_LIBRARIES") {
            let libraryPath = String(cString: libraries)
            if !libraryPath.isEmpty {
                logger?.debug("DYLD_INSERT_LIBRARIES detected: \(libraryPath)")
                return true
            }
        }

        return false
    }

    private func canFork() -> Bool {
        // On non-jailbroken devices, fork() will fail due to sandbox restrictions
        let pid = fork()
        if pid >= 0 {
            // fork succeeded - device is likely jailbroken
            if pid > 0 {
                // Parent process - kill child
                kill(pid, SIGTERM)
            }
            logger?.debug("fork() succeeded - sandbox compromised")
            return true
        }
        return false
    }

    // MARK: - Debugger Detection

    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride

        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }

        let isDebugged = (info.kp_proc.p_flag & P_TRACED) != 0
        if isDebugged {
            logger?.debug("Debugger detected via P_TRACED flag")
        }

        return isDebugged
    }

    // MARK: - Runtime Modifications

    private func hasSuspiciousRuntimeModifications() -> Bool {
        // Check for suspicious dynamic libraries loaded
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName).lowercased()

                // Check for common hooking/instrumentation libraries
                let suspiciousLibraries = [
                    "substrate",
                    "substitute",
                    "cycript",
                    "frida",
                    "cynject",
                ]

                for suspicious in suspiciousLibraries {
                    if name.contains(suspicious) {
                        logger?.debug("Suspicious library loaded: \(name)")
                        return true
                    }
                }
            }
        }

        return false
    }
}

/// Security validation error
struct SecurityValidationError: Error, CustomStringConvertible {
    let findings: [String]

    var description: String {
        return "Device security validation failed: " + findings.joined(separator: "; ")
    }

    var localizedDescription: String {
        return description
    }
}
