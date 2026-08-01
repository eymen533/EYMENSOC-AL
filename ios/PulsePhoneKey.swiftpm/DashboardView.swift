import SwiftUI
import WebKit

/// Pulse Dash HUD inside Playgrounds (same idea as Android HudActivity).
struct DashboardView: View {
    let serverURL: String
    let pinHint: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("← Pair") { dismiss() }
                Spacer()
                Text("Pulse HUD")
                    .font(.headline)
                Spacer()
                Link("Safari", destination: url)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            Text("PIN: \(pinHint)  ·  Login gerekirse yaz")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            DashWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarHidden(true)
    }

    private var url: URL {
        var s = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = "https://example.com" }
        if !s.hasPrefix("http") { s = "https://\(s)" }
        while s.hasSuffix("/") { s.removeLast() }
        return URL(string: s + "/") ?? URL(string: "https://example.com")!
    }
}

struct DashWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.customUserAgent = (wv.value(forKey: "userAgent") as? String ?? "") + " TeslaPulseiPad/9"
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url?.host != url.host {
            uiView.load(URLRequest(url: url))
        }
    }
}
