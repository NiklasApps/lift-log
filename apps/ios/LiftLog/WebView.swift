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
        // The page asks Claude through the app when a key is saved (Settings → Claude).
        let hasKey = ClaudeKey.value != nil
        config.userContentController.addUserScript(WKUserScript(
            source: "window.liftlogApp = { claudeKey: \(hasKey) };", injectionTime: .atDocumentStart, forMainFrameOnly: true))
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
    /// Claude answers being written, by the page's call id, so the page can stop one.
    private var calls: [String: Task<Void, Never>] = [:]

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "haptic":
            // Rest over: a full vibration, not a light tap, so it's felt with the phone on the bench.
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        case "restAlarm":
            Notify.rest(at: (body["at"] as? NSNumber)?.doubleValue ?? 0, emom: body["emom"] as? Bool ?? false)
        case "weekly":
            Notify.weekly(last: body["last"] as? String ?? "")
        case "awake":
            UIApplication.shared.isIdleTimerDisabled = body["on"] as? Bool ?? false
        case "share":
            guard let name = body["name"] as? String, let text = body["text"] as? String else { return }
            share(name: name, text: text, from: message.webView)
        case "claude":
            guard let id = body["id"] as? String, let turns = body["messages"] as? [[String: Any]] else { return }
            ask(id: id, tier: body["tier"] as? String ?? "default", turns: turns, web: message.webView)
        case "claudeCancel":
            guard let id = body["id"] as? String else { return }
            calls.removeValue(forKey: id)?.cancel()
        case "claudeKey":
            setKey((body["key"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines), web: message.webView)
        default:
            break
        }
    }

    /// Streams Claude's answer to window.__liftlogClaude(id, {type: "text" | "done" | "error", …}).
    private func ask(id: String, tier: String, turns: [[String: Any]], web: WKWebView?) {
        let messages = turns.compactMap { t -> [String: String]? in
            guard let role = t["role"] as? String, let content = t["content"] as? String, !content.isEmpty else { return nil }
            return ["role": role, "content": content]
        }
        calls[id] = Task { [weak self, weak web] in
            var last = Date.distantPast
            var reply: [String: Any]
            do {
                let r = try await Claude.stream(tier: tier, messages: messages) { text in
                    // a few updates a second are enough to read along
                    guard Date().timeIntervalSince(last) > 0.08 else { return }
                    last = Date()
                    Bridge.call(web, "__liftlogClaude", id, ["type": "text", "text": text])
                }
                reply = ["type": "done", "text": r.text, "stop": r.stop]
            } catch let e as ClaudeError {
                reply = ["type": "error", "code": e.code, "message": e.message]
            } catch {
                reply = ["type": "error", "code": "upstream_error", "message": error.localizedDescription]
            }
            Bridge.call(web, "__liftlogClaude", id, reply)
            DispatchQueue.main.async { self?.calls[id] = nil }
        }
    }

    /// An empty key removes it. A new key is tried once before it's saved.
    private func setKey(_ key: String, web: WKWebView?) {
        if key.isEmpty {
            ClaudeKey.delete()
            Bridge.call(web, "__liftlogClaudeKey", ["ok": true, "has": false] as [String: Any])
            return
        }
        Task { [weak web] in
            if let code = await Claude.check(key) {
                Bridge.call(web, "__liftlogClaudeKey", ["ok": false, "code": code, "has": ClaudeKey.value != nil] as [String: Any])
            } else {
                let saved = ClaudeKey.save(key)
                Bridge.call(web, "__liftlogClaudeKey", ["ok": saved, "code": saved ? "" : "keychain", "has": ClaudeKey.value != nil] as [String: Any])
            }
        }
    }

    /// Calls window[fn](…args) in the page, with each argument as JSON.
    private static func call(_ web: WKWebView?, _ fn: String, _ args: Any...) {
        let json = args.compactMap { a -> String? in
            guard let d = try? JSONSerialization.data(withJSONObject: a, options: .fragmentsAllowed) else { return nil }
            return String(data: d, encoding: .utf8)
        }
        DispatchQueue.main.async {
            web?.evaluateJavaScript("window.\(fn) && window.\(fn)(\(json.joined(separator: ",")))", completionHandler: nil)
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
