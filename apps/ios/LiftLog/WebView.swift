import AudioToolbox
import SwiftUI
import WebKit

/// liftlog.html (bundled) in a web view. It is served from liftlog://app/
/// rather than file:// so its localStorage has a stable origin.
struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Bridge { Bridge() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: "liftlog")
        config.userContentController.add(context.coordinator, name: "liftlog")
        // The rest timer beeps through Web Audio without a tap first.
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .appBackground
        web.scrollView.backgroundColor = .appBackground
        // The page pads itself with env(safe-area-inset-*).
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.load(URLRequest(url: URL(string: "liftlog://app/liftlog.html")!))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}

/// What the page asks of the app: window.webkit.messageHandlers.liftlog.postMessage({type, …}).
final class Bridge: NSObject, WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "haptic":
            // Rest over: a full vibration, not a light tap, so it's felt with the phone on the bench.
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        case "awake":
            UIApplication.shared.isIdleTimerDisabled = body["on"] as? Bool ?? false
        case "share":
            guard let name = body["name"] as? String, let text = body["text"] as? String else { return }
            share(name: name, text: text, from: message.webView)
        default:
            break
        }
    }

    /// The backup file goes to the share sheet (Save to Files, AirDrop, Mail …).
    private func share(name: String, text: String, from web: WKWebView?) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        guard (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil,
              var top = web?.window?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        top.present(UIActivityViewController(activityItems: [url], applicationActivities: nil), animated: true)
    }
}

/// Serves bundled files for liftlog://app/<name>.
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    private static let types = ["html": "text/html; charset=utf-8", "json": "application/json", "png": "image/png", "svg": "image/svg+xml"]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url,
              let file = Bundle.main.url(forResource: url.lastPathComponent, withExtension: nil),
              let data = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let type = Self.types[file.pathExtension.lowercased()] ?? "application/octet-stream"
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": type, "Content-Length": String(data.count)])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
