
extension DescopeClient.JWTResponse {
    func convert() throws -> DescopeSession {
        let sessionToken = try Token(jwt: sessionJwt)
        guard let refreshJwt else { throw DescopeError.decodeError.with(message: "Missing refresh JWT") }
        let refreshToken = try Token(jwt: refreshJwt)
        return Session(sessionToken: sessionToken, refreshToken: refreshToken)
    }
}
