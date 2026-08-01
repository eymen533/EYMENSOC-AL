import Foundation

/// Talks to the real Tesla Pulse Dash server (same APIs as Android).
enum PulseSession {
    struct Config {
        var server: String
        var pin: String
        var vin: String
    }

    static func normalizeServer(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return s }
        if !s.hasPrefix("http") { s = "https://\(s)" }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    /// Unlock + mark HUD pair session on the server. Returns cookies for WKWebView.
    static func prepareHUD(config: Config) async throws -> [HTTPCookie] {
        let base = normalizeServer(config.server)
        guard let baseURL = URL(string: base) else { throw SessError.badURL }

        let jar = HTTPCookieStorage.shared
        jar.cookies(for: baseURL)?.forEach { jar.deleteCookie($0) }

        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpCookieStorage = jar
        cfg.httpCookieAcceptPolicy = .always
        let session = URLSession(configuration: cfg)
        // 1) PIN unlock
        _ = try await postJSON(
            session: session,
            url: baseURL.appendingPathComponent("api/auth/unlock"),
            body: ["pin": config.pin],
            cookieJar: jar,
            base: baseURL
        )
        // 2) Mirror Android: vin → card → pair so Dash leaves "demo" and shows live HUD
        let vin = config.vin.uppercased()
        _ = try? await postJSON(
            session: session,
            url: baseURL.appendingPathComponent("api/ble/vin"),
            body: ["vin": vin],
            cookieJar: jar,
            base: baseURL
        )
        _ = try? await postJSON(
            session: session,
            url: baseURL.appendingPathComponent("api/ble/card"),
            body: [:],
            cookieJar: jar,
            base: baseURL
        )
        _ = try? await postJSON(
            session: session,
            url: baseURL.appendingPathComponent("api/ble/pair"),
            body: [
                "vin": vin,
                "card_tapped": true,
                "source": "ios",
            ],
            cookieJar: jar,
            base: baseURL
        )

        return jar.cookies(for: baseURL) ?? []
    }

    private static func postJSON(
        session: URLSession,
        url: URL,
        body: [String: Any],
        cookieJar: HTTPCookieStorage,
        base: URL
    ) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let cookies = cookieJar.cookies(for: base), !cookies.isEmpty {
            let header = HTTPCookie.requestHeaderFields(with: cookies)
            header.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 25

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse {
            let headers = http.allHeaderFields.reduce(into: [String: String]()) { acc, kv in
                if let k = kv.key as? String { acc[k] = "\(kv.value)" }
            }
            let newCookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: base)
            newCookies.forEach { cookieJar.setCookie($0) }
            guard (200...299).contains(http.statusCode) else {
                let err = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                throw SessError.http(http.statusCode, err ?? String(data: data, encoding: .utf8) ?? "")
            }
        }
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return obj
    }

    enum SessError: LocalizedError {
        case badURL, http(Int, String)
        var errorDescription: String? {
            switch self {
            case .badURL: return "Server URL hatali"
            case .http(let c, let m): return "Sunucu \(c): \(m)"
            }
        }
    }
}
