
import Foundation

class DescopeClient: HTTPClient {
    let config: DescopeConfig
    
    init(config: DescopeConfig) {
        self.config = config
        super.init(baseURL: config.baseURL, logger: config.logger, networkClient: config.networkClient)
    }
    
    // MARK: - OTP
    
    func otpSignUp(with method: DeliveryMethod, loginId: String, details: SignUpDetails?) async throws -> MaskedAddress {
        return try await post("auth/otp/signup/\(method.rawValue)", body: [
            "loginId": loginId,
            "user": details?.dictValue,
        ])
    }
    
    func otpSignIn(with method: DeliveryMethod, loginId: String, refreshJwt: String?, options: LoginOptions?) async throws -> MaskedAddress {
        return try await post("auth/otp/signin/\(method.rawValue)", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "loginOptions": options?.dictValue,
        ])
    }
    
    func otpSignUpIn(with method: DeliveryMethod, loginId: String, refreshJwt: String?, options: LoginOptions?) async throws -> MaskedAddress {
        return try await post("auth/otp/signup-in/\(method.rawValue)", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "loginOptions": options?.dictValue,
        ])
    }
    
    func otpVerify(with method: DeliveryMethod, loginId: String, code: String) async throws -> JWTResponse {
        return try await post("auth/otp/verify/\(method.rawValue)", body: [
            "loginId": loginId,
            "code": code,
        ])
    }
    
    func otpUpdateEmail(_ email: String, loginId: String, refreshJwt: String, options: UpdateOptions) async throws -> MaskedAddress {
        return try await post("auth/otp/update/email", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "email": email,
            "addToLoginIDs": options.contains(.addToLoginIds),
            "onMergeUseExisting": options.contains(.onMergeUseExisting),
        ])
    }
    
    func otpUpdatePhone(_ phone: String, with method: DeliveryMethod, loginId: String, refreshJwt: String, options: UpdateOptions) async throws -> MaskedAddress {
        try method.ensurePhoneMethod()
        return try await post("auth/otp/update/phone/\(method.rawValue)", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "phone": phone,
            "addToLoginIDs": options.contains(.addToLoginIds),
            "onMergeUseExisting": options.contains(.onMergeUseExisting),
        ])
    }
    
    // MARK: - TOTP
    
    struct TOTPResponse: JSONResponse {
        var provisioningURL: String
        var image: String
        var key: String
    }
    
    func totpSignUp(loginId: String, details: SignUpDetails?) async throws -> TOTPResponse {
        return try await post("auth/totp/signup", body: [
            "loginId": loginId,
            "user": details?.dictValue,
        ])
    }
    
    func totpVerify(loginId: String, code: String, refreshJwt: String?, options: LoginOptions?) async throws -> JWTResponse {
        return try await post("auth/totp/verify", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "code": code,
            "loginOptions": options?.dictValue,
        ])
    }
    
    func totpUpdate(loginId: String, refreshJwt: String) async throws -> TOTPResponse {
        return try await post("auth/totp/update", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
        ])
    }
    
    // MARK: - Password
    
    func passwordSignUp(loginId: String, password: String, details: SignUpDetails?) async throws -> JWTResponse {
        return try await post("auth/password/signup", body: [
            "loginId": loginId,
            "user": details?.dictValue,
            "password": password,
        ])
    }
    
    func passwordSignIn(loginId: String, password: String) async throws -> JWTResponse {
        return try await post("auth/password/signin", body: [
            "loginId": loginId,
            "password": password,
        ])
    }
    
    func passwordUpdate(loginId: String, newPassword: String, refreshJwt: String) async throws {
        try await post("auth/password/update", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "newPassword": newPassword,
        ])
    }
    
    func passwordReplace(loginId: String, oldPassword: String, newPassword: String) async throws {
        try await post("auth/password/replace", body: [
            "loginId": loginId,
            "oldPassword": oldPassword,
            "newPassword": newPassword,
        ])
    }
    
    func passwordSendReset(loginId: String, redirectURL: String?) async throws {
        try await post("auth/password/reset", body: [
            "loginId": loginId,
            "redirectUrl": redirectURL,
        ])
    }
    
    struct PasswordPolicyResponse: JSONResponse {
        var minLength: Int
        var lowercase: Bool
        var uppercase: Bool
        var number: Bool
        var nonAlphanumeric: Bool
    }
    
    func passwordGetPolicy() async throws -> PasswordPolicyResponse {
        return try await get("auth/password/policy")
    }

    
    // MARK: - Magic Link
    
    func magicLinkSignUp(with method: DeliveryMethod, loginId: String, details: SignUpDetails?, redirectURL: String?) async throws -> MaskedAddress {
        return try await post("auth/magiclink/signup/\(method.rawValue)", body: [
            "loginId": loginId,
            "user": details?.dictValue,
            "redirectUrl": redirectURL,
        ])
    }
    
    func magicLinkSignIn(with method: DeliveryMethod, loginId: String, redirectURL: String?, refreshJwt: String?, options: LoginOptions?) async throws -> MaskedAddress {
        return try await post("auth/magiclink/signin/\(method.rawValue)", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "redirectUrl": redirectURL,
            "loginOptions": options?.dictValue,
        ])
    }
    
    func magicLinkSignUpOrIn(with method: DeliveryMethod, loginId: String, redirectURL: String?, refreshJwt: String?, options: LoginOptions?) async throws -> MaskedAddress {
        return try await post("auth/magiclink/signup-in/\(method.rawValue)", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "redirectUrl": redirectURL,
            "loginOptions": options?.dictValue,
        ])
    }
    
    func magicLinkVerify(token: String) async throws -> JWTResponse {
        return try await post("auth/magiclink/verify", body: [
            "token": token,
        ])
    }
    
    func magicLinkUpdateEmail(_ email: String, loginId: String, redirectURL: String?, refreshJwt: String, options: UpdateOptions) async throws -> MaskedAddress {
        return try await post("auth/magiclink/update/email", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "email": email,
            "redirectUrl": redirectURL,
            "addToLoginIDs": options.contains(.addToLoginIds),
            "onMergeUseExisting": options.contains(.onMergeUseExisting),
        ])
    }
    
    func magicLinkUpdatePhone(_ phone: String, with method: DeliveryMethod, loginId: String, redirectURL: String?, refreshJwt: String, options: UpdateOptions) async throws -> MaskedAddress {
        try method.ensurePhoneMethod()
        return try await post("auth/magiclink/update/phone/\(method.rawValue)", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "phone": phone,
            "redirectUrl": redirectURL,
            "addToLoginIDs": options.contains(.addToLoginIds),
            "onMergeUseExisting": options.contains(.onMergeUseExisting),
        ])
    }
    
    // MARK: - Enchanted Link
    
    struct EnchantedLinkResponse: JSONResponse {
        var linkId: String
        var pendingRef: String
        var maskedEmail: String
    }
    
    func enchantedLinkSignUp(loginId: String, details: SignUpDetails?, redirectURL: String?) async throws -> EnchantedLinkResponse {
        return try await post("auth/enchantedlink/signup/email", body: [
            "loginId": loginId,
            "user": details?.dictValue,
            "redirectUrl": redirectURL,
        ])
    }
    
    func enchantedLinkSignIn(loginId: String, redirectURL: String?, refreshJwt: String?, options: LoginOptions?) async throws -> EnchantedLinkResponse {
        try await post("auth/enchantedlink/signin/email", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "redirectUrl": redirectURL,
            "loginOptions": options?.dictValue,
        ])
    }
    
    func enchantedLinkSignUpOrIn(loginId: String, redirectURL: String?, refreshJwt: String?, options: LoginOptions?) async throws -> EnchantedLinkResponse {
        try await post("auth/enchantedlink/signup-in/email", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "redirectUrl": redirectURL,
            "loginOptions": options?.dictValue,
        ])
    }
    
    func enchantedLinkUpdateEmail(_ email: String, loginId: String, redirectURL: String?, refreshJwt: String, options: UpdateOptions) async throws -> EnchantedLinkResponse {
        return try await post("auth/enchantedlink/update/email", headers: authorization(with: refreshJwt), body: [
            "loginId": loginId,
            "email": email,
            "redirectUrl": redirectURL,
            "addToLoginIDs": options.contains(.addToLoginIds),
            "onMergeUseExisting": options.contains(.onMergeUseExisting),
        ])
    }
    
    func enchantedLinkPendingSession(pendingRef: String) async throws -> JWTResponse {
        return try await post("auth/enchantedlink/pending-session", body: [
            "pendingRef": pendingRef,
        ])
    }
    
    // MARK: - OAuth
    
    struct OAuthResponse: JSONResponse {
        var url: String
    }
    
    func oauthStart(provider: OAuthProvider, redirectURL: String?, refreshJwt: String?, options: LoginOptions?) async throws -> OAuthResponse {
        return try await post("auth/oauth/authorize", headers: authorization(with: refreshJwt), params: [
            "provider": provider.rawValue,
            "redirectUrl": redirectURL
        ], body: options?.dictValue ?? [:])
    }
    
    func oauthExchange(code: String) async throws -> JWTResponse {
        return try await post("auth/oauth/exchange", body: [
            "code": code
        ])
    }

    // MARK: - SSO
    
    struct SSOResponse: JSONResponse {
        var url: String
    }
    
    func ssoStart(emailOrTenantName: String, redirectURL: String?, refreshJwt: String?, options: LoginOptions?) async throws -> OAuthResponse {
        return try await post("auth/saml/authorize", headers: authorization(with: refreshJwt), params: [
            "tenant": emailOrTenantName,
            "redirectUrl": redirectURL
        ], body: options?.dictValue ?? [:])
    }
    
    func ssoExchange(code: String) async throws -> JWTResponse {
        return try await post("auth/saml/exchange", body: [
            "code": code
        ])
    }
    
    // MARK: - Access Key
    
    struct AccessKeyExchangeResponse: JSONResponse {
        var sessionJwt: String
    }
    
    func accessKeyExchange(_ accessKey: String) async throws -> AccessKeyExchangeResponse {
        return try await post("auth/accesskey/exchange", headers: authorization(with: accessKey))
    }
    
    // Mark: - Flow
    
    func flowExchange(authorizationCode: String, codeVerifier: String) async throws -> JWTResponse {
        return try await post("flow/exchange", body: [
            "authorizationCode": authorizationCode,
            "codeVerifier": codeVerifier,
        ])
    }
    
    // MARK: - Others
    
    func me(refreshJwt: String) async throws -> UserResponse {
        return try await get("me", headers: authorization(with: refreshJwt))
    }
    
    func refresh(refreshJwt: String) async throws -> JWTResponse {
        return try await post("refresh", headers: authorization(with: refreshJwt))
    }
    
    func logout(refreshJwt: String) async throws {
        try await post("logout", headers: authorization(with: refreshJwt))
    }
    
    // MARK: - Shared
    
    static let refreshCookieName = "DSR"
    
    struct JWTResponse: JSONResponse {
        var sessionJwt: String
        var refreshJwt: String?
        var user: UserResponse?
        var firstSeen: Bool
        
        mutating func setValues(from response: HTTPURLResponse) {
            guard let url = response.url, let fields = response.allHeaderFields as? [String: String] else { return }
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
            for cookie in cookies where cookie.name == refreshCookieName {
                refreshJwt = cookie.value
            }
        }
    }
    
    struct UserResponse: JSONResponse {
        var userId: String
        var loginIds: [String]
        var name: String?
        var picture: String?
        var email: String?
        var verifiedEmail: Bool = false
        var phone: String?
        var verifiedPhone: Bool = false
        var createdTime: Int
    }
    
    struct MaskedAddress: JSONResponse {
        var maskedEmail: String?
        var maskedPhone: String?
    }
    
    struct LoginOptions {
        var stepup: Bool = false
        var mfa: Bool = false
        var customClaims: [String: Any] = [:]

        var dictValue: [String: Any?] {
            return [
                "stepup": stepup ? true : nil,
                "mfa": mfa ? true : nil,
                "customClaims": customClaims.isEmpty ? nil : customClaims,
            ]
        }
    }
    
    // MARK: - Internal
    
    override var basePath: String {
        return "v1"
    }
    
    override var defaultHeaders: [String: String] {
        return [
            "Authorization": "Bearer \(config.projectId)",
            "x-descope-sdk-name": "swift",
            "x-descope-sdk-version": DescopeSDK.version,
        ]
    }
    
    override func errorForResponseData(_ data: Data) -> Error? {
        return DescopeError(errorResponse: data)
    }
    
    private func authorization(with value: String?) -> [String: String] {
        guard let value else { return [:] }
        return ["Authorization": "Bearer \(config.projectId):\(value)"]
    }
}

private extension SignUpDetails {
    var dictValue: [String: Any?] {
        return [
            "name": name,
            "phone": phone,
            "email": email,
        ]
    }
}

private extension DeliveryMethod {
    func ensurePhoneMethod() throws {
        if self != .sms && self != .whatsapp {
            throw DescopeError.invalidArguments.with(message: "Update phone can be done using SMS or WhatsApp only")
        }
    }
}
