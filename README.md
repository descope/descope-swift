# DescopeKit

DescopeKit is the Descope SDK for Swift. It provides convenient access
to the Descope user management and authentication APIs for applications
written in Swift. You can read more on the [Descope Website](https://descope.com).

## Setup

Add the `DescopeKit` package using the Swift package manager. Within Xcode,
go to `File` > `Add Package Dependencies` and enter the URL of the repo in
the search box at the top of the dialog:

```
https://github.com/descope/descope-swift
```

Set the dependency rule as appropriate and press the `Copy Dependency` button
to confirm. The project navigator panel will show `DescopeKit` under package
dependencies and you can `import DescopeKit` in your code.

Note that the Descope SDK supports projects with a deployment target of iOS 13
and above and macOS 12 and above.

## Quickstart 

A Descope `Project ID` is required to initialize the SDK. Find it
on the [project page](https://app.descope.com/settings/project) in
the Descope Console.

```swift
import DescopeKit

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Descope.setup(projectId: "<Your-Project-Id>")
    return true
}
```

You can authenticate a user in your application by starting one of the
authentication methods. For example, let's use OTP via email: 

```swift
// sends an OTP code to the given email address
try await Descope.otp.signUp(with: .email, loginId: "andy@example.com", details: nil)
```

We finish the authentication by verifying the OTP code the user entered: 

```swift
// if the user entered the right code the authentication is successful  
let authResponse = try await Descope.otp.verify(with: .email, loginId: "andy@example.com", code: code)

// we create a DescopeSession object that represents an authenticated user session
let session = DescopeSession(from: authResponse)

// the session manager takes care of saving the session to the keychain and
// refreshing it for us as needed
Descope.sessionManager.manageSession(session)
```

The session manager will automatically load the session from the keychain
the next time the application is launched. At that point we might check if
there's a logged in user to decide which screen to show:

```swift
func initialViewController() -> UIViewController {
    // check if we have a valid session from a previous launch and that it hasn't expired yet 
    if let session = Descope.sessionManager.session, !session.refreshToken.isExpired {
        print("Authenticated user found: \(session.user)")
        return MainViewController()
    }
    return LoginViewController()
}
```

We use the active session to authenticate an outgoing API request to the
application's backend:

```swift
var request = URLRequest(url: url)
try await request.setAuthorizationHTTPHeaderField(from: Descope.sessionManager)
let (data, response) = try await URLSession.shared.data(for: request)
```

## Session Management

The `DescopeSessionManager` class is used to manage an authenticated
user session for an application.

The session manager takes care of loading and saving the session as well
as ensuring that it's refreshed when needed. For the default instances of
the `DescopeSessionManager` class this means using the keychain for secure
storage of the session and refreshing it a short while before it expires.

Once the user completes a sign in flow successfully you should set the
`DescopeSession` object as the active session of the session manager.

```swift
let authResponse = try await Descope.otp.verify(with: .email, loginId: "andy@example.com", code: "123456")
let session = DescopeSession(from: authResponse)
Descope.sessionManager.manageSession(session)
```

The session manager can then be used at any time to ensure the session
is valid and to authenticate outgoing requests to your backend with a
bearer token authorization header.

```swift
var request = URLRequest(url: url)
try await request.setAuthorizationHTTPHeaderField(from: Descope.sessionManager)
let (data, response) = try await URLSession.shared.data(for: request)
```

If your backend uses a different authorization mechanism you can of course
use the session JWT directly instead of the extension function. You can either
add another extension function on `URLRequest` such as the one above, or you
can do the following.

```swift
try await Descope.sessionManager.refreshSessionIfNeeded()
guard let sessionJwt = Descope.sessionManager.session?.sessionJwt else { throw ServerError.unauthorized }
request.setValue(sessionJwt, forHTTPHeaderField: "X-Auth-Token")
```

When the application is relaunched the `DescopeSessionManager` loads any
existing session automatically, so you can check straight away if there's
an authenticated user.

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Descope.setup(projectId: "...")
    if let session = Descope.sessionManager.session, !session.refreshToken.isExpired {
        print("User is logged in: \(session)")
    }
    return true
}
```

When the user wants to sign out of the application you only need to call
the `clearSession()` method to make the session manager clear its session
and also delete it from the keychain.

```swift
Descope.sessionManager.clearSession()
```

If you also want to remove the user's refresh JWT from the Descope servers
once it becomes redundant you can call the `Descope.auth.revokeSessions()`
function. See its documentation for more details.

## Session Storage

DescopeKit uses a pluggable session storage system defiend by `DescopeSessionStorage`. By default, authenticated sessions are stored securely in the system keychain and automatically restored when the application restarts.

## Customizing Keychain Storage

The default session storage uses a keychain-backed store. You can customize its behavior by configuring a `SessionStorage.KeychainStore`.

```swift
let keychainStore = SessionStorage.KeychainStore()
keychainStore.accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
keychainStore.service = "com.descope.DescopeKit"
keychainStore.label = "DescopeSession"

let storage = SessionStorage(
projectId: "<Your-Project-Id>",
store: keychainStore
)

Descope.sessionManager = DescopeSessionManager(storage: storage)
```

### Sharing sessions between app and extensions

To share sessions between an app and its extensions, configure a keychain access group:

```swift
keychainStore.accessGroup = "group.com.example.myapp"
```

> Important: Changing the `service`, `label`, or `accessGroup` values in an app update will cause previously stored sessions to be lost and users will need to sign in again.

## App Launch and Background Considerations

On iOS, the default keychain accessibility (`kSecAttrAccessibleAfterFirstUnlock`) means sessions are available only after the device has been unlocked at least once following a restart.

In rare cases (for example, background launches triggered by Bluetooth,
push notifications, or app extensions), the app may start before the keychain
is accessible. In such scenarios:

- The session may appear temporarily unavailable
- This should not be treated as an explicit logout
- The session may become available later in the app lifecycle

If your application requires different behavior, consider customizing the
keychain accessibility level.

## Flows

We can authenticate users by building and running Flows. Flows are built in the Descope 
[flow editor](https://app.descope.com/flows). The editor allows you to easily define both
the behavior and the UI that take the user through their authentication journey. Read more
about it in the Descope [getting started](https://docs.descope.com/build/guides/gettingstarted/)
guide.

### Define and host your flow

Before we can run a flow, it must first be defined and hosted. Every project comes with a
set of predefined flows out of the box. You can customize your flows to suit your needs
and host them somewhere on the web. Follow the [getting started](https://docs.descope.com/build/guides/gettingstarted/)
guide for more details.

### Enable Universal Links for Magic Link authentication

If your flows use Magic Link authentication, the user will need to be routed back to the
app when they tap on the link in the authentication email message. If you don't intend to
use Magic Link authentication you can skip this step. Otherwise, see Apple's [universal links](https://developer.apple.com/ios/universal-links/)
guide to learn more.

When your application delegate is notified about a universal link being triggered, you'll
need to provide it to the flow so it can continue with the authentication. See the documentation
for `Descope.handleURL` for more details.

```swift
func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else { return false }
    let handled = Descope.handleURL(url)
    return handled
}
```

### Start the flow

You can use either a `DescopeFlowViewController` or a `DescopeFlowView` to run a flow.
The former provides a ready made component to present a flow modally with a few lines
of code, while the latter can be used to show the flow however you want in your view
hierarchy. See the documentation for both classes for more details.

```swift
func showLoginScreen() {
    let flow = DescopeFlow(url: "https://example.com/myflow")

    let flowViewController = DescopeFlowViewController()
    flowViewController.delegate = self
    flowViewController.start(flow: flow)

    navigationController?.pushViewController(flowViewController, animated: true)
}

func flowViewControllerDidFinish(_ controller: DescopeFlowViewController, response: AuthenticationResponse) {
    let session = DescopeSession(from: response)
    Descope.sessionManager.manageSession(session)
    showMainScreen()
}
```

### Customizing the flow

You can use hooks to customize how the flow page looks or behaves when running as
a native flow. For example, these hooks will override the flow page to have a
transparent background and set a margin on the body element.

```swift
let flow = DescopeFlow(url: "https://example.com/myflow")
flow.hooks = [
    .setTransparentBody,
    .addStyles(selector: "body", rules: ["margin: 16px"]),
]
```

See the documentation for `DescopeFlowHook` for more examples on using hooks and how
to create your own.

## Authentication Methods

Here are some examples for how to authenticate users:

### OTP Authentication

Send a user a one-time password (OTP) using your preferred delivery
method (_email / SMS_). An email address or phone number must be
provided accordingly.

The user can either `sign up`, `sign in` or `sign up or in`

```swift
// Every user must have a loginId. All other user details are optional:
try await Descope.otp.signUp(with: .email, loginId: "andy@example.com", details: SignUpDetails(
    name: "Andy Rhoads"
))
```

The user will receive a code using the selected delivery method. Verify
that code using:

```swift
let authResponse = try await Descope.otp.verify(with: .email, loginId: "andy@example.com", code: "123456")
let session = DescopeSession(from: authResponse)
Descope.sessionManager.manageSession(session)
```

### Magic Link

Send a user a Magic Link using your preferred delivery method (_email / SMS_).
The Magic Link will redirect the user to page where the its token needs
to be verified. This redirection can be configured in code, or globally
in the [Descope Console](https://app.descope.com/settings/authentication/magiclink)

The user can either `sign up`, `sign in` or `sign up or in`

```swift
// If configured globally, the redirect URI is optional. If provided however, it will be used
// instead of any global configuration
try await Descope.magiclink.signUp(with: .email, loginId: "andy@example.com", details: nil)
```

To verify a magic link, your redirect page must call the validation function
on the token (`t`) parameter (`https://your-redirect-address.com/verify?t=<token>`):

```swift
let authResponse = try await Descope.magiclink.verify(token: "<token>")
```

### OAuth

When a user wants to use social login with Apple you can leverage the [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/)
feature to show a native authentication view that allows the user to login using the Apple ID
they are already logged into on their device. Note that the OAuth provider you choose to use
must be configured with the application's Bundle Identifier as the Client ID in the
[Descope console](https://app.descope.com/settings/authentication/social).

```swift
do {
    showLoading(true)
    let authResponse = try await Descope.oauth.native(provider: .apple, options: [])
    let session = DescopeSession(from: authResponse)
    Descope.sessionManager.manageSession(session)
    showHomeScreen() 
} catch .oauthNativeCancelled {
    showLoading(false)
    print("Authentication cancelled")
} catch {
    showError(error)
}
```

Users can authenticate using any other social login providers, using the OAuth protocol via
a browser based authentication flow. Configure your OAuth settings on the [Descope console](https://app.descope.com/settings/authentication/social).
To start an OAuth authentication call:

```swift
// Choose an oauth provider out of the supported providers
// If configured globally, the redirect URL is optional. If provided however, it will be used
// instead of any global configuration.
// Redirect the user to the returned URL to start the OAuth redirect chain
let authURL = try await Descope.oauth.start(provider: .github, redirectURL: "exampleauthschema://my-app.com/handle-oauth", options: [])
```

Take the generated URL and authenticate the user using `ASWebAuthenticationSession`
(read more [here](https://developer.apple.com/documentation/authenticationservices/authenticating_a_user_through_a_web_service)).
The user will authenticate with the authentication provider, and will be
redirected back to the redirect URL, with an appended `code` HTTP URL parameter.
Exchange it to validate the user:

```swift
// Start the authentication session
let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "exampleauthschema") { callbackURL, error in
    // Extract the returned code
    guard let url = callbackURL else { return }
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else { return }
    
    Task {
        // Exchange code for session
        let authResponse = try await Descope.oauth.exchange(code: code)
        let session = DescopeSession(from: authResponse)
        Descope.sessionManager.manageSession(session)
    }
}
```

### SSO/SAML

Users can authenticate to a specific tenant using SAML or Single Sign On.
Configure your SSO/SAML settings on the [Descope console](https://app.descope.com/settings/authentication/sso).
To start a flow call:

```swift
// Choose which tenant to log into
// If configured globally, the return URL is optional. If provided however, it will be used
// instead of any global configuration.
// Redirect the user to the returned URL to start the SSO/SAML redirect chain
let authURL = try await Descope.sso.start(emailOrTenantName: "my-tenant-ID", redirectURL: "exampleauthschema://my-app.com/handle-saml", options: [])
```

Take the generated URL and authenticate the user using `ASWebAuthenticationSession`
(read more [here](https://developer.apple.com/documentation/authenticationservices/authenticating_a_user_through_a_web_service)).
The user will authenticate with the authentication provider, and will be redirected
back to the redirect URL, with an appended `code` HTTP URL parameter. Exchange it
to validate the user:

```swift
// Start the authentication session
let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "exampleauthschema") { callbackURL, error in

    // Extract the returned code
    guard let url = callbackURL else {return}
    let component = URLComponents(url: url, resolvingAgainstBaseURL: false)
    guard let code = component?.queryItems?.first(where: {$0.name == "code"})?.value else { return }

    // ... Trigger asynchronously

    // Exchange code for session
    let authResponse = try await Descope.sso.exchange(code: code)
    let session = DescopeSession(from: authResponse)
    Descope.sessionManager.manageSession(session)
}
```

### Passkeys

Users can authenticate by creating or using a [passkey](https://fidoalliance.org/passkeys/).
Configure your Passkey/WebAuthn settings on the [Descope console](https://app.descope.com/settings/authentication/webauthn).
Make sure it is enabled and that the top level domain is configured correctly.

After that, go through Apple's [Supporting passkeys](https://developer.apple.com/documentation/authenticationservices/public-private_key_authentication/supporting_passkeys/)
guide, in particular be sure to have an associated domain configured for your app
with the `webcredentials` service type, whose value matches the top level domain
you configured in the Descope console earlier.

```swift
do {
    showLoading(true)
    let authResponse = try await Descope.passkey.signUpOrIn(loginId: "andy@example.com", options: [])
    let session = DescopeSession(from: authResponse)
    Descope.sessionManager.manageSession(session)
    showHomeScreen() 
} catch .oauthNativeCancelled {
    showLoading(false)
    print("Authentication cancelled")
} catch {
    showError(error)
}
```

### TOTP Authentication

The user can authenticate using an authenticator app, such as Google Authenticator.
Sign up like you would using any other authentication method. The sign up response
will then contain a QR code `image` that can be displayed to the user to scan using
their mobile device camera app, or the user can enter the `key` manually or click
on the link provided by the `provisioningURL`.

Existing users can add TOTP using the `update` function.

```swift
// Every user must have a loginID. All other user information is optional
let totpResponse = try await Descope.totp.signUp(loginId: "andy@example.com", details: nil)

// Use one of the provided options to have the user add their credentials to the authenticator
// totpResponse.provisioningURL
// totpResponse.key
```

There are 3 different ways to allow the user to save their credentials in their
authenticator app - either by clicking the provisioning URL, scanning the QR
image or inserting the key manually. After that, signing in is done using the
code the app produces.

```swift
let authResponse = try await Descope.totp.verify(loginId: "andy@example.com", code: "987654")
```

### Password Authentication

Create a new user that can later sign in with a password:

```swift
let authResponse = try await Descope.password.signUp(loginId: "andy@example.com", password: "securePassword123!", details: SignUpDetails(
    name: "Andy Rhoads"
))

// in another screen

let authResponse = try await Descope.password.signIn(loginId: "andy@example.com", password: "securePassword123!")
```

You can update the current password for a logged in user:

```swift
try await Descope.password.update(loginId: "andy@example.com", newPassword: "newSecurePassword456!", refreshJwt: "user-refresh-jwt")
```

You can also replace the password for a user by providing both the new password and
the current one:

```swift
let authResponse = try await Descope.password.replace(loginId: "andy@example.com", oldPassword: "SecurePassword123!", newPassword: "NewSecurePassword456!")
```

You can also trigger a password reset email to be sent to the user:

```swift
try await Descope.password.sendReset(loginId: "andy@example.com", redirectURL: "appscheme://my-app.com/handle-reset")
```

## Support

#### Contributing

If anything is missing or not working correctly please open an issue or pull request.

#### Learn more

To learn more please see the [Descope documentation](https://docs.descope.com).

#### Contact us

If you need help you can hop on our [Slack community](https://www.descope.com/community) or send an email to [Descope support](mailto:support@descope.com).
