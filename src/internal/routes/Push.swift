
final class Push: DescopePush {
    let client: DescopeClient
    
    init(client: DescopeClient) {
        self.client = client
    }
    
    func enroll(token: String, development: Bool, refreshJwt: String) async throws {
        let provider = development ? "apndev" : "apn"
        try await client.pushEnrollDevice(provider: provider, token: token, device: SystemInfo.device ?? "iPhone", refreshJwt: refreshJwt)
    }
    
    func finish(transactionId: String, result: String, refreshJwt: String) async throws {
        try await client.pushSignInFinish(transactionId: transactionId, result: result, refreshJwt: refreshJwt)
    }
}
