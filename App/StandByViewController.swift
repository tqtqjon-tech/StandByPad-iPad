import UIKit
import WebKit
import Network

final class StandByViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView!
    private let monitor = NWPathMonitor()
    private var network: [String: Any] = ["online": NSNull(), "type": "unknown", "interfaces": []]
    private var observations: [NSObjectProtocol] = []
    private var assetsURL: URL?

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        UIDevice.current.isBatteryMonitoringEnabled = true
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.add(WeakMessageHandler(self), name: "standByPad")
        guard let shimURL = Bundle.main.url(forResource: "native-bridge", withExtension: "js"),
              let shim = try? String(contentsOf: shimURL, encoding: .utf8),
              let index = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebAssets") else {
            let label = UILabel(frame: view.bounds)
            label.text = "StandByPad resources are missing. Please rebuild the app."
            label.textColor = .white
            label.numberOfLines = 0
            label.textAlignment = .center
            view.addSubview(label)
            return
        }
        configuration.userContentController.addUserScript(WKUserScript(source: shim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        assetsURL = index.deletingLastPathComponent()
        webView.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
        for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification, UIApplication.didBecomeActiveNotification] {
            observations.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.publishState() })
        }
        monitor.pathUpdateHandler = { [weak self] path in
            let types: [(NWInterface.InterfaceType, String)] = [(.wifi, "wifi"), (.cellular, "cellular"), (.wiredEthernet, "ethernet")]
            let interfaces: [String] = types.compactMap { type, name in
                path.usesInterfaceType(type) ? name : nil
            }
            DispatchQueue.main.async {
                self?.network = ["online": path.status == .satisfied, "type": path.status == .satisfied ? (interfaces.first ?? "other") : "none", "interfaces": interfaces, "expensive": path.isExpensive, "constrained": path.isConstrained]
                self?.publishState()
            }
        }
        monitor.start(queue: DispatchQueue(label: "tech.tqtqjon.standbypad.network"))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        publishState()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.isFileURL == true,
              let command = message.body as? String, command == "getState" else { return }
        publishState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { publishState() }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let allowed = url.isFileURL && assetsURL.map { url.standardizedFileURL.path.hasPrefix($0.standardizedFileURL.path + "/") } == true
        decisionHandler(allowed ? .allow : .cancel)
    }

    private func publishState() {
        guard webView != nil else { return }
        let device = UIDevice.current
        let batteryState: String
        switch device.batteryState {
        case .charging: batteryState = "charging"
        case .full: batteryState = "full"
        case .unplugged: batteryState = "unplugged"
        default: batteryState = "unknown"
        }
        let level: Any = device.batteryLevel >= 0 ? Double(device.batteryLevel) : NSNull()
        let charging: Any = batteryState == "unknown" ? NSNull() : (batteryState == "charging" || batteryState == "full")
        let bounds = view.bounds
        let orientation = view.window?.windowScene?.interfaceOrientation
        let orientationName: String
        switch orientation {
        case .landscapeLeft: orientationName = "landscapeLeft"
        case .landscapeRight: orientationName = "landscapeRight"
        case .portrait: orientationName = "portrait"
        case .portraitUpsideDown: orientationName = "portraitUpsideDown"
        default: orientationName = "unknown"
        }
        let state: [String: Any] = [
            "battery": ["level": level, "percent": device.batteryLevel >= 0 ? Int((device.batteryLevel * 100).rounded()) as Any : NSNull(), "charging": charging, "state": batteryState],
            "network": network,
            "device": ["systemName": device.systemName, "systemVersion": device.systemVersion, "model": device.model, "name": device.name],
            "screen": ["width": bounds.width, "height": bounds.height, "scale": view.window?.screen.scale ?? UIScreen.main.scale, "orientation": orientationName]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: state), let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.StandByPadNative && window.StandByPadNative._receive(\(json));", completionHandler: nil)
    }

    deinit {
        monitor.cancel()
        observations.forEach(NotificationCenter.default.removeObserver)
    }
}

private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
