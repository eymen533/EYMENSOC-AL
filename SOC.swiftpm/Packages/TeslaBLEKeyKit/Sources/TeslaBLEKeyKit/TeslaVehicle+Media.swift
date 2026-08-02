import Foundation
#if !COCOAPODS
import TeslaBLEKeyKitCore
#endif

extension TeslaVehicle {
    public func mediaTogglePlayback() async throws {
        var action = CarServer_VehicleAction()
        action.mediaPlayAction = CarServer_MediaPlayAction()
        try await sendVehicleAction(action)
    }

    public func mediaNextTrack() async throws {
        var action = CarServer_VehicleAction()
        action.mediaNextTrack = CarServer_MediaNextTrack()
        try await sendVehicleAction(action)
    }

    public func mediaPreviousTrack() async throws {
        var action = CarServer_VehicleAction()
        action.mediaPreviousTrack = CarServer_MediaPreviousTrack()
        try await sendVehicleAction(action)
    }

    public func mediaNextFavorite() async throws {
        var action = CarServer_VehicleAction()
        action.mediaNextFavorite = CarServer_MediaNextFavorite()
        try await sendVehicleAction(action)
    }

    public func mediaPreviousFavorite() async throws {
        var action = CarServer_VehicleAction()
        action.mediaPreviousFavorite = CarServer_MediaPreviousFavorite()
        try await sendVehicleAction(action)
    }

    public func mediaAdjustVolume(delta: Int32) async throws {
        var action = CarServer_VehicleAction()
        var volume = CarServer_MediaUpdateVolume()
        volume.mediaVolume = .volumeDelta(delta)
        action.mediaUpdateVolume = volume
        try await sendVehicleAction(action)
    }

    public func mediaSetVolume(absolute: Float) async throws {
        var action = CarServer_VehicleAction()
        var volume = CarServer_MediaUpdateVolume()
        volume.mediaVolume = .volumeAbsoluteFloat(absolute)
        action.mediaUpdateVolume = volume
        try await sendVehicleAction(action)
    }
}
