import Foundation
import SwiftUI
import UIKit
import Combine

/// Tesla BLE does not send album art URLs — resolve cover via iTunes Search (no API key).
@MainActor
final class MediaArtworkStore: ObservableObject {
    static let shared = MediaArtworkStore()

    @Published private(set) var imageURL: URL?
    @Published private(set) var image: UIImage?

    private var lastQuery = ""
    private var task: Task<Void, Never>?
    private var cache: [String: URL] = [:]

    func resolve(title: String, artist: String) {
        let t = sanitize(title)
        let a = sanitize(artist)
        guard !t.isEmpty || !a.isEmpty else {
            imageURL = nil
            image = nil
            lastQuery = ""
            return
        }
        let q = [a, t].filter { !$0.isEmpty }.joined(separator: " ")
        guard q != lastQuery else { return }
        lastQuery = q
        if let hit = cache[q] {
            imageURL = hit
            loadImage(hit)
            return
        }
        task?.cancel()
        task = Task { await fetch(query: q) }
    }

    private func sanitize(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == "—" || t == "-" || t == "--" { return "" }
        return t
    }

    private func fetch(query: String) async {
        var comps = URLComponents(string: "https://itunes.apple.com/search")
        comps?.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "country", value: "TR"),
        ]
        guard let url = comps?.url else { return }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = obj["results"] as? [[String: Any]],
                  let first = results.first,
                  let art = first["artworkUrl100"] as? String else { return }
            let hi = art
                .replacingOccurrences(of: "100x100bb", with: "600x600bb")
                .replacingOccurrences(of: "100x100", with: "600x600")
            guard let artURL = URL(string: hi) else { return }
            guard !Task.isCancelled else { return }
            cache[query] = artURL
            imageURL = artURL
            loadImage(artURL)
        } catch {
            // Keep previous art on transient errors.
        }
    }

    private func loadImage(_ url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let img = UIImage(data: data) else { return }
                await MainActor.run { self.image = img }
            } catch {}
        }
    }
}

struct AlbumArtView: View {
    var image: UIImage?
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.28, blue: 0.22),
                            Color(red: 0.35, green: 0.08, blue: 0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.32, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }
}
