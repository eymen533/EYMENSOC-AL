import Foundation
import SwiftUI
import UIKit
import Combine

/// Tesla BLE has no cover URL — resolve via Deezer + iTunes (no API key).
@MainActor
final class MediaArtworkStore: ObservableObject {
    static let shared = MediaArtworkStore()

    @Published private(set) var imageURL: URL?
    @Published private(set) var image: UIImage?
    @Published private(set) var loading = false

    private var lastSuccessQuery = ""
    private var inflightQuery = ""
    private var task: Task<Void, Never>?
    private var cache: [String: URL] = [:]

    func resolve(title: String, artist: String, album: String = "") {
        let t = sanitize(title)
        let a = sanitize(artist)
        let al = sanitize(album)
        guard !t.isEmpty || !a.isEmpty else {
            imageURL = nil
            image = nil
            loading = false
            lastSuccessQuery = ""
            inflightQuery = ""
            return
        }
        let q = [a, t, al].filter { !$0.isEmpty }.joined(separator: " ")
        if q == lastSuccessQuery, image != nil || imageURL != nil { return }
        if q == inflightQuery, loading { return }

        if let hit = cache[q] {
            lastSuccessQuery = q
            imageURL = hit
            loadImage(hit)
            return
        }

        inflightQuery = q
        loading = true
        // Clear stale cover while searching new track.
        if q != lastSuccessQuery {
            image = nil
            imageURL = nil
        }
        task?.cancel()
        task = Task { await fetchBest(query: q, title: t, artist: a, album: al) }
    }

    private func sanitize(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == "—" || t == "-" || t == "--" { return "" }
        return t
    }

    private func fetchBest(query: String, title: String, artist: String, album: String) async {
        let attempts: [String] = [
            query,
            [artist, title].filter { !$0.isEmpty }.joined(separator: " "),
            [title, artist].filter { !$0.isEmpty }.joined(separator: " "),
            title,
            [artist, album].filter { !$0.isEmpty }.joined(separator: " "),
        ].filter { !$0.isEmpty }

        var seen = Set<String>()
        for term in attempts {
            let key = term.lowercased()
            guard seen.insert(key).inserted else { continue }
            // Await each provider separately — Swift forbids `await` inside `??`.
            var url = await searchDeezer(term)
            if url == nil { url = await searchITunes(term, country: "TR") }
            if url == nil { url = await searchITunes(term, country: "US") }
            if let url {
                guard !Task.isCancelled else { return }
                cache[query] = url
                lastSuccessQuery = query
                inflightQuery = ""
                loading = false
                imageURL = url
                loadImage(url)
                return
            }
        }
        guard !Task.isCancelled else { return }
        inflightQuery = ""
        loading = false
    }

    private func searchDeezer(_ term: String) async -> URL? {
        var comps = URLComponents(string: "https://api.deezer.com/search")
        comps?.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = comps?.url else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = obj["data"] as? [[String: Any]],
                  let first = results.first,
                  let album = first["album"] as? [String: Any] else { return nil }
            let art = (album["cover_xl"] as? String)
                ?? (album["cover_big"] as? String)
                ?? (album["cover_medium"] as? String)
            guard let art, let artURL = URL(string: art) else { return nil }
            return artURL
        } catch {
            return nil
        }
    }

    private func searchITunes(_ term: String, country: String) async -> URL? {
        var comps = URLComponents(string: "https://itunes.apple.com/search")
        comps?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "3"),
            URLQueryItem(name: "country", value: country),
        ]
        guard let url = comps?.url else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = obj["results"] as? [[String: Any]] else { return nil }
            for row in results {
                guard let art = row["artworkUrl100"] as? String else { continue }
                let hi = art
                    .replacingOccurrences(of: "100x100bb", with: "600x600bb")
                    .replacingOccurrences(of: "100x100", with: "600x600")
                if let artURL = URL(string: hi) { return artURL }
            }
            return nil
        } catch {
            return nil
        }
    }

    private func loadImage(_ url: URL) {
        Task {
            do {
                var req = URLRequest(url: url, timeoutInterval: 12)
                req.setValue("image/*", forHTTPHeaderField: "Accept")
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let img = UIImage(data: data) else { return }
                await MainActor.run {
                    self.image = img
                    self.objectWillChange.send()
                }
            } catch {}
        }
    }
}

struct AlbumArtView: View {
    var image: UIImage?
    var url: URL?
    var loading: Bool = false
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            AlbumArtFill(image: image, url: url, loading: loading, noteSize: size * 0.32)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }
}

/// Full-bleed album art (map-style panel background).
struct AlbumArtFill: View {
    var image: UIImage?
    var url: URL?
    var loading: Bool = false
    var noteSize: CGFloat = 48

    var body: some View {
        ZStack {
            // Neutral dark canvas — never full-screen brand-red (YouTube accent stays on the icon only).
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.16),
                    Color(red: 0.04, green: 0.05, blue: 0.07),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "music.note")
                            .font(.system(size: noteSize, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    default:
                        ProgressView().tint(.white)
                    }
                }
            } else if loading {
                ProgressView().tint(.white)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: noteSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
