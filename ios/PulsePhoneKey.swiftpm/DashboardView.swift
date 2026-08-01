import SwiftUI
import WebKit

struct DashboardView: View {
    @Binding var serverURL: String
    var pin: String = "428462"
    @Environment(\.dismiss) private var dismiss
    @State private var reloadToken = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button("Pair") { dismiss() }
                Spacer()
                Text("Pulse HUD")
                    .font(.headline)
                Spacer()
                Button("Yenile") { reloadToken += 1 }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))

            Text("Login PIN: \(pin)")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            DashWebView(urlString: serverURL, reloadToken: reloadToken)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct DashWebView: UIViewRepresentable {
    let urlString: String
    let reloadToken: Int

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.bounces = false
        load(wv)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.lastToken != reloadToken {
            context.coordinator.lastToken = reloadToken
            load(wv)
        }
    }

    private func load(_ wv: WKWebView) {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return }
        if !s.hasPrefix("http") { s = "https://\(s)" }
        while s.hasSuffix("/") { s.removeLast() }
        guard let url = URL(string: s + "/") else { return }
        wv.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60))
    }

    final class Coord: NSObject, WKNavigationDelegate {
        var lastToken = -1
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("HUD nav fail \(error.localizedDescription)")
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("HUD provisional fail \(error.localizedDescription)")
        }
    }
}
