import Combine
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class NowPlayingService: ObservableObject {
    static let shared = NowPlayingService()

    struct Track: Equatable {
        var title: String
        var artist: String
        var artwork: UIImage?
        var isPlaying: Bool
        var sourceName: String
    }

    @Published private(set) var track: Track?

    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        guard let info else {
            track = nil
            return
        }

        let title = info[MPMediaItemPropertyTitle] as? String ?? "Bilinmeyen parça"
        let artist = info[MPMediaItemPropertyArtist] as? String ?? ""
        let artwork: UIImage?
        if let mpArtwork = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            artwork = mpArtwork.image(at: CGSize(width: 300, height: 300))
        } else {
            artwork = nil
        }

        let rate = info[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0
        track = Track(
            title: title,
            artist: artist,
            artwork: artwork,
            isPlaying: rate > 0,
            sourceName: "Now Playing"
        )
    }
}
