import Foundation
import Security

/// The Anthropic API key, kept in the Keychain on this device. The page never sees it.
enum ClaudeKey {
    private static let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "de.niklasapps.liftlog.claude",
        kSecAttrAccount as String: "api-key",
    ]

    static var value: String? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        var add = item
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func delete() { SecItemDelete(item as CFDictionary) }
}

/// `code` is what the page branches on, the same names claude.ai's sample capability uses where they overlap.
struct ClaudeError: Error {
    let code: String
    let message: String
}

/// The Claude Messages API over raw HTTP (there's no official Swift SDK), streamed.
enum Claude {
    private static let version = "2026-10-21"
    private static let base = URL(string: "https://api.anthropic.com/v1/")!

    /// `tier` as the page names it: "quick" for short reads of questionnaire answers, anything else for coaching.
    /// `onText` gets the whole answer so far.
    static func stream(tier: String, messages: [[String: String]], onText: @escaping (String) -> Void) async throws -> (text: String, stop: String) {
        guard let key = ClaudeKey.value else { throw ClaudeError(code: "no_key", message: "No API key") }
        let quick = tier == "quick"
        var body: [String: Any] = [
            "model": quick ? "claude-haiku-5-5" : "claude-opus-5-5",
            "max_tokens": quick ? 4000 : 32000,
            "stream": true,
            "messages": messages,
            "output_config": ["effort": quick ? "low" : "medium"],
        ]
        var req = request("messages", key: key)
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        if !quick {
            // a request Claude declines is run again on Anthropic's recommended fallback model instead of failing
            body["fallbacks"] = "default"
            req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let opened: (URLSession.AsyncBytes, URLResponse)
        do { opened = try await URLSession.shared.bytes(for: req) } catch { throw network(error) }
        let (bytes, response) = opened
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            var raw = Data()
            do { for try await b in bytes { raw.append(b) } } catch {}
            throw apiError(status: status, body: raw)
        }

        var text = "", stop = ""
        do {
            for try await line in bytes.lines {
                guard line.hasPrefix("data:"),
                      let ev = try? JSONSerialization.jsonObject(with: Data(line.dropFirst(5).utf8)) as? [String: Any] else { continue }
                switch ev["type"] as? String {
                case "content_block_delta":
                    if let d = ev["delta"] as? [String: Any], d["type"] as? String == "text_delta", let t = d["text"] as? String {
                        text += t
                        onText(text)
                    }
                case "message_delta":
                    if let d = ev["delta"] as? [String: Any], let s = d["stop_reason"] as? String { stop = s }
                case "error":
                    let e = ev["error"] as? [String: Any]
                    throw ClaudeError(code: "upstream_error", message: e?["message"] as? String ?? "Stream error")
                default:
                    break
                }
            }
        } catch let e as ClaudeError {
            throw e
        } catch {
            throw network(error)
        }
        if stop == "refusal" { throw ClaudeError(code: "refused", message: "Claude declined") }
        return (text, stop)
    }

    /// nil when the key works; otherwise an error code for the page.
    static func check(_ key: String) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request("models?limit=1", key: key))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return status == 200 ? nil : apiError(status: status, body: data).code
        } catch {
            return network(error).code
        }
    }

    private static func request(_ path: String, key: String) -> URLRequest {
        var req = URLRequest(url: URL(string: path, relativeTo: base)!)
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue(version, forHTTPHeaderField: "anthropic-version")
        return req
    }

    private static func network(_ error: Error) -> ClaudeError {
        if error is CancellationError { return ClaudeError(code: "cancelled", message: "Cancelled") }
        if let u = error as? URLError {
            switch u.code {
            case .cancelled: return ClaudeError(code: "cancelled", message: "Cancelled")
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut:
                return ClaudeError(code: "offline", message: u.localizedDescription)
            default: break
            }
        }
        return ClaudeError(code: "upstream_error", message: error.localizedDescription)
    }

    private static func apiError(status: Int, body: Data) -> ClaudeError {
        let e = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["error"] as? [String: Any]
        let message = e?["message"] as? String ?? "HTTP \(status)"
        switch status {
        case 401, 403: return ClaudeError(code: "invalid_key", message: message)
        case 429: return ClaudeError(code: "rate_limited", message: message)
        case 413: return ClaudeError(code: "prompt_too_large", message: message)
        case 400 where message.lowercased().contains("credit"): return ClaudeError(code: "no_credit", message: message)
        case 400: return ClaudeError(code: "invalid_request", message: message)
        default: return ClaudeError(code: "upstream_error", message: message)
        }
    }
}
