import SwiftUI
import VisionKit
import AVFoundation

/// Camera VIN reader — DataScanner (text) when available, otherwise paste-only fallback alert.
struct VINScannerSheet: View {
    @Binding var vin: String
    @Environment(\.dismiss) private var dismiss
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
                    VINDataScannerRepresentable { scanned in
                        vin = KeyStore.normalizeVIN(scanned)
                        KeyStore.saveVIN(vin)
                        dismiss()
                    }
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Bu cihazda canlı VIN tarayıcı yok.")
                            .font(.headline)
                        Text("Tesla uygulamasından VIN’i kopyalayıp Yapıştır kullan, veya Settings’ten manuel gir.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Kapat") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("VIN tara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .alert("Tarama", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("Tamam", role: .cancel) { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }
}

/// VisionKit live text scanner — picks 17-char VIN from the camera feed.
struct VINDataScannerRepresentable: UIViewControllerRepresentable {
    var onVIN: (String) -> Void

    func makeCoordinator() -> Coord { Coord(onVIN: onVIN) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        context.coordinator.scanner = vc
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coord) {
        uiViewController.stopScanning()
    }

    final class Coord: NSObject, DataScannerViewControllerDelegate {
        let onVIN: (String) -> Void
        weak var scanner: DataScannerViewController?
        private var didFire = false

        init(onVIN: @escaping (String) -> Void) {
            self.onVIN = onVIN
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            consider(items: addedItems + allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            consider(items: updatedItems + allItems)
        }

        private func consider(items: [RecognizedItem]) {
            guard !didFire else { return }
            for item in items {
                guard case .text(let text) = item else { continue }
                if let vin = Self.extractVIN(from: text.transcript) {
                    didFire = true
                    scanner?.stopScanning()
                    DispatchQueue.main.async { self.onVIN(vin) }
                    return
                }
            }
        }

        /// Pull a plausible 17-char VIN from OCR noise.
        static func extractVIN(from raw: String) -> String? {
            let upper = raw.uppercased()
            // Direct match
            let compact = KeyStore.normalizeVIN(upper)
            if KeyStore.isValidVIN(compact) { return compact }
            // Sliding window over alphanumeric runs
            let cleaned = upper.map { ch -> Character in
                (ch.isLetter || ch.isNumber) ? ch : " "
            }
            let joined = String(cleaned)
            for token in joined.split(separator: " ") {
                let t = String(token)
                if KeyStore.isValidVIN(t) { return t }
                if t.count > 17 {
                    for i in 0...(t.count - 17) {
                        let start = t.index(t.startIndex, offsetBy: i)
                        let end = t.index(start, offsetBy: 17)
                        let slice = String(t[start..<end])
                        if KeyStore.isValidVIN(slice) { return slice }
                    }
                }
            }
            return nil
        }
    }
}
