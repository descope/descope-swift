
import Foundation
import CommonCrypto

/// Handles TLS certificate pinning validation
class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let pins: [String: [String]]
    private let logger: DescopeLogger?

    /// Creates a certificate pinning delegate
    /// - Parameters:
    ///   - pins: Dictionary mapping hostnames to arrays of SHA-256 public key hashes (base64-encoded)
    ///   - logger: Optional logger for debugging certificate validation
    init(pins: [String: [String]], logger: DescopeLogger?) {
        self.pins = pins
        self.logger = logger
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let host = challenge.protectionSpace.host

        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            return (.performDefaultHandling, nil)
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logger?.error("Server trust is nil for \(host)")
            return (.cancelAuthenticationChallenge, nil)
        }

        // Check if we have pins configured for this host
        guard let expectedPins = pins[host], !expectedPins.isEmpty else {
            // No pins configured for this host - use default validation
            logger?.debug("No certificate pins configured for \(host), using default validation")
            return (.performDefaultHandling, nil)
        }

        // Perform certificate pinning validation
        let validationResult = validateCertificatePin(serverTrust: serverTrust, expectedPins: expectedPins, host: host)

        switch validationResult {
        case .success:
            logger?.debug("Certificate pin validation succeeded for \(host)")
            return (.useCredential, URLCredential(trust: serverTrust))

        case .failure(let error):
            logger?.error("Certificate pin validation failed for \(host): \(error)")
            return (.cancelAuthenticationChallenge, nil)
        }
    }

    private func validateCertificatePin(serverTrust: SecTrust, expectedPins: [String], host: String) -> Result<Void, Error> {
        // Evaluate the server trust (performs default certificate validation)
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            let nsError = error as Error? ?? NSError(domain: "CertificatePinning", code: -1, userInfo: [NSLocalizedDescriptionKey: "Default certificate validation failed"])
            return .failure(nsError)
        }

        // Get the certificate chain
        guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate], !certificates.isEmpty else {
            return .failure(NSError(domain: "CertificatePinning", code: -2, userInfo: [NSLocalizedDescriptionKey: "No certificates in chain"]))
        }

        // Extract public key hashes from the certificate chain
        let publicKeyHashes = certificates.compactMap { extractPublicKeyHash(from: $0) }

        guard !publicKeyHashes.isEmpty else {
            return .failure(NSError(domain: "CertificatePinning", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to extract public keys from certificates"]))
        }

        // Check if any hash matches our expected pins
        let normalizedExpectedPins = expectedPins.map { normalizePin($0) }
        let pinMatched = publicKeyHashes.contains { hash in
            normalizedExpectedPins.contains(hash)
        }

        guard pinMatched else {
            // Log the actual hashes for debugging (only in unsafe mode)
            if logger?.unsafe == true {
                logger?.debug("Expected pins: \(expectedPins)")
                logger?.debug("Actual hashes: \(publicKeyHashes)")
            }
            return .failure(NSError(domain: "CertificatePinning", code: -4, userInfo: [
                NSLocalizedDescriptionKey: "Certificate pin mismatch",
                NSLocalizedFailureReasonErrorKey: "None of the server's public keys matched the expected pins for \(host)"
            ]))
        }

        return .success(())
    }

    private func extractPublicKeyHash(from certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }

        // Compute SHA-256 hash of the public key
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        publicKeyData.withUnsafeBytes { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else { return }
            CC_SHA256(baseAddress, CC_LONG(publicKeyData.count), &hash)
        }

        // Encode as base64
        let hashData = Data(hash)
        return "sha256/" + hashData.base64EncodedString()
    }

    private func normalizePin(_ pin: String) -> String {
        // Ensure pin has sha256/ prefix
        if pin.hasPrefix("sha256/") {
            return pin
        } else {
            return "sha256/" + pin
        }
    }
}
