import SwiftUI
import WebKit

/// Real Tesla Pulse Dash (same UI as the web cluster) — not a fake gauge.
struct RealHUDView: View {
    let server: String
    let pin: String
    let vin: String
    var onBack: () -> Void

    @State private var status = "Dash hazirlaniyor…"
    @State private var error: String?
    @State private var webView = WKWebView(frame: .zero, configuration: RealHUDView.makeConfig())
    @State private var ready = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RealWebView(webView: webView)
                .ignoresSafeArea()
                .opacity(ready ? 1 : 0.15)

            if !ready || error != nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Tekrar dene") { Task { await boot() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.85))
            }

            Button(action: onBack) {
                Label("Pair", systemImage: "chevron.left")
                    .font(.caption.bold())
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(12)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task { await boot() }
    }

    private func boot() async {
        ready = false
        error = nil
        status = "PIN ile giris…"
        do {
            let cookies = try await PulseSession.prepareHUD(
                config: .init(server: server, pin: pin, vin: vin)
            )
            status = "Cerezler…"
            let store = webView.configuration.websiteDataStore.httpCookieStore
            for c in cookies {
                await store.setCookie(c)
            }
            status = "HUD yukleniyor…"
            let base = PulseSession.normalizeServer(server)
            guard let url = URL(string: base + "/") else { throw PulseSession.SessError.badURL }
            await MainActor.run {
                webView.customUserAgent = (webView.value(forKey: "userAgent") as? String ?? "")
                    + " TeslaPulseiPad/12"
                webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
                ready = true
                status = "Hazir"
            }
        } catch {
            self.error = error.localizedDescription
            status = "HUD acilamadi"
        }
    }

    static func makeConfig() -> WKWebViewConfiguration {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.websiteDataStore = .default()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        cfg.defaultWebpagePreferences = prefs
        return cfg
    }
}

struct RealWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView {
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
