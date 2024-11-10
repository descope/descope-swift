
#if os(iOS)

import UIKit
import WebKit

@MainActor
public protocol DescopeFlowViewDelegate: AnyObject {
    func flowViewDidUpdateState(_ flowView: DescopeFlowView, to state: DescopeFlowState, from previous: DescopeFlowState)
    func flowViewDidBecomeReady(_ flowView: DescopeFlowView)
    func flowViewDidInterceptNavigation(_ flowView: DescopeFlowView, url: URL, external: Bool)
    func flowViewDidFailAuthentication(_ flowView: DescopeFlowView, error: DescopeError)
    func flowViewDidFinishAuthentication(_ flowView: DescopeFlowView, response: AuthenticationResponse)
}

/// A view for showing authentication screens built using [Descope Flows](https://app.descope.com/flows).
///
/// You can use a flow view as the main view of a modal authentication screen or as part of a
/// more complex view hierarchy. In the former case you might consider using a ``DescopeFlowViewController``
/// instead, as it provides simple way to present an authentication flow modally.
///
/// You can create an instance of ``DescopeFlowView``, add it to the view hierarchy, and call
/// ``start(flow:)`` to load the flow.
///
/// ```swift
/// override func viewDidLoad() {
///     super.viewDidLoad()
///
///     let flowView = DescopeFlowView(frame: bounds)
///     flowView.delegate = self
///     flowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
///     view.addSubview(flowView)
///
///     let flowURL = URL(string: "https://example.com/myflow")!
///     let flow = DescopeFlow(url: flowURL)
///     flowView.start(flow: flow)
/// }
/// ```
///
/// The flow view only handles presentation and its `delegate` is expected to handle the
/// events as appropriate.
///
/// ```swift
/// extension MyClass: DescopeFlowViewDelegate {
///     public func flowViewDidUpdateState(_ flowView: DescopeFlowView, to state: DescopeFlowState, from previous: DescopeFlowState) {
///         // for example, show a loading indicator when state is .started and hide it otherwise
///     }
///
///     public func flowViewDidBecomeReady(_ flowView: DescopeFlowView) {
///         // for example, animate the view in if it's been hidden until now
///     }
///
///     public func flowViewDidInterceptNavigation(_ flowView: DescopeFlowView, url: URL, external: Bool) {
///         UIApplication.shared.open(url) // open any links in the user's default browser app
///     }
///
///     public func flowViewDidFailAuthentication(_ flowView: DescopeFlowView, error: DescopeError) {
///         // called when the flow fails, because of a network error or some other reason
///         let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
///         alert.addAction(UIAlertAction(title: "OK", style: .cancel))
///         self.present(alert, animated: true)
///     }
///
///     public func flowViewDidFinishAuthentication(_ flowView: DescopeFlowView, response: AuthenticationResponse) {
///         let session = DescopeSession(from: response)
///         Descope.sessionManager.manageSession(session)
///         // for example, transition the app to some other screen
///     }
/// }
/// ```
///
/// - Important: There are many possibilities for customization when you consider all
///     the various `UIKit` properties on the view itself and the various CSS rules in
///     the flow webpage being displayed. If you need any additional customization
///     options that are not currently exposed by ``DescopeFlowView`` you can open
///     an issue or pull request [here](https://github.com/descope/swift-sdk).
open class DescopeFlowView: UIView {

    private let coordinator = DescopeFlowCoordinator()

    private lazy var webView = createWebView()

    private lazy var delegateWrapper = CoordinatorDelegateWrapper(view: self)

    /// A delegate object for receiving events about the state of the flow.
    public weak var delegate: DescopeFlowViewDelegate?

    /// The current state of the ``DescopeFlowView``.
    public var state: DescopeFlowState {
        return coordinator.state
    }

    // Initialization

    public convenience init() {
        self.init(frame: .zero)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        coordinator.delegate = delegateWrapper
        coordinator.webView = webView
        addSubview(webView)
    }

    // UIView

    open override func layoutSubviews() {
        super.layoutSubviews()
        webView.frame = bounds
    }

    // Flow

    /// Loads and displays a Descope Flow.
    ///
    /// You can call this method while the view is hidden to prepare the flow ahead of time,
    /// watching for updates via the delegate, and showing the view when it's ready.
    ///
    /// ```swift
    /// let flowURL = URL(string: "https://example.com/myflow")!
    /// let flow = DescopeFlow(url: flowURL)
    /// flowView.start(flow: flow)
    /// ```
    public func start(flow: DescopeFlow) {
        coordinator.start(flow: flow)
    }

    // WebView

    private func createWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        _prepareConfiguration(configuration)

        let webViewClass = Self.webViewClass
        let webView = webViewClass.init(frame: bounds, configuration: configuration)
        _prepareWebView(webView)

        return webView
    }

    private func _prepareConfiguration(_ configuration: WKWebViewConfiguration) {
        prepareConfiguration(configuration)
        coordinator.prepare(configuration: configuration)
    }

    private func _prepareWebView(_ webView: WKWebView) {
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.keyboardDismissMode = .interactiveWithAccessory
        prepareWebView(webView)
    }

    // Override points

    /// Override this method if you need your ``DescopeFlowView`` subclass to use a
    /// custom `WKWebView` subclass for its webview instance.
    ///
    /// The default implementation of this method returns `WKWebView.self`.
    open class var webViewClass: WKWebView.Type {
        return WKWebView.self
    }

    /// Override this method if you need to customize the webview's configuration before it's created.
    ///
    /// The default implementation of this method does nothing.
    open func prepareConfiguration(_ configuration: WKWebViewConfiguration) {
    }

    /// Override this method if you need to customize the webview itself after it's created.
    ///
    /// The default implementation of this method does nothing.
    open func prepareWebView(_ webView: WKWebView) {
    }

    // Delegation points (not public for now)

    func didUpdateState(to state: DescopeFlowState, from previous: DescopeFlowState) {
        delegate?.flowViewDidUpdateState(self, to: state, from: previous)
    }

    func didBecomeReady() {
        delegate?.flowViewDidBecomeReady(self)
    }

    func didInterceptNavigation(url: URL, external: Bool) {
        delegate?.flowViewDidInterceptNavigation(self, url: url, external: external)
    }

    func didFailAuthentication(error: DescopeError) {
        delegate?.flowViewDidFailAuthentication(self, error: error)
    }

    func didFinishAuthentication(response: AuthenticationResponse) {
        delegate?.flowViewDidFinishAuthentication(self, response: response)
    }
}

private class CoordinatorDelegateWrapper: DescopeFlowCoordinatorDelegate {
    private weak var view: DescopeFlowView?

    init(view: DescopeFlowView) {
        self.view = view
    }

    func coordinatorDidUpdateState(_ coordinator: DescopeFlowCoordinator, to state: DescopeFlowState, from previous: DescopeFlowState) {
        view?.didUpdateState(to: state, from: previous)
    }

    func coordinatorDidBecomeReady(_ coordinator: DescopeFlowCoordinator) {
        view?.didBecomeReady()
    }

    func coordinatorDidInterceptNavigation(_ coordinator: DescopeFlowCoordinator, url: URL, external: Bool) {
        view?.didInterceptNavigation(url: url, external: external)
    }

    func coordinatorDidFailAuthentication(_ coordinator: DescopeFlowCoordinator, error: DescopeError) {
        view?.didFailAuthentication(error: error)
    }

    func coordinatorDidFinishAuthentication(_ coordinator: DescopeFlowCoordinator, response: AuthenticationResponse) {
        view?.didFinishAuthentication(response: response)
    }
}

#endif
