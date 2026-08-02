import Foundation
#if !COCOAPODS
import TeslaBLEKeyKitCore
#endif

public enum SunroofAction: Sendable {
    case vent
    case close
    case open
}

public enum WindowAction: Sendable {
    case vent
    case close
}

extension TeslaVehicle {
    public func flashLights() async throws {
        var action = CarServer_VehicleAction()
        action.vehicleControlFlashLightsAction = CarServer_VehicleControlFlashLightsAction()
        try await sendVehicleAction(action)
    }

    public func honkHorn() async throws {
        var action = CarServer_VehicleAction()
        action.vehicleControlHonkHornAction = CarServer_VehicleControlHonkHornAction()
        try await sendVehicleAction(action)
    }

    public func setSentryMode(enabled: Bool) async throws {
        var action = CarServer_VehicleAction()
        var sentry = CarServer_VehicleControlSetSentryModeAction()
        sentry.on = enabled
        action.vehicleControlSetSentryModeAction = sentry
        try await sendVehicleAction(action)
    }

    public func setValetMode(enabled: Bool, password: String = "") async throws {
        var action = CarServer_VehicleAction()
        var valet = CarServer_VehicleControlSetValetModeAction()
        valet.on = enabled
        valet.password = password
        action.vehicleControlSetValetModeAction = valet
        try await sendVehicleAction(action)
    }

    public func resetValetPin() async throws {
        var action = CarServer_VehicleAction()
        action.vehicleControlResetValetPinAction = CarServer_VehicleControlResetValetPinAction()
        try await sendVehicleAction(action)
    }

    public func controlSunroof(_ sunroofAction: SunroofAction) async throws {
        var action = CarServer_VehicleAction()
        var sunroof = CarServer_VehicleControlSunroofOpenCloseAction()
        switch sunroofAction {
        case .vent:
            sunroof.action = .vent(CarServer_Void())
        case .close:
            sunroof.action = .close(CarServer_Void())
        case .open:
            sunroof.action = .open(CarServer_Void())
        }
        action.vehicleControlSunroofOpenCloseAction = sunroof
        try await sendVehicleAction(action)
    }

    public func controlWindows(_ windowAction: WindowAction) async throws {
        var action = CarServer_VehicleAction()
        var window = CarServer_VehicleControlWindowAction()
        switch windowAction {
        case .vent:
            window.action = .vent(CarServer_Void())
        case .close:
            window.action = .close(CarServer_Void())
        }
        action.vehicleControlWindowAction = window
        try await sendVehicleAction(action)
    }

    public func triggerHomelink(latitude: Float, longitude: Float) async throws {
        var action = CarServer_VehicleAction()
        var homelink = CarServer_VehicleControlTriggerHomelinkAction()
        var location = CarServer_LatLong()
        location.latitude = latitude
        location.longitude = longitude
        homelink.location = location
        action.vehicleControlTriggerHomelinkAction = homelink
        try await sendVehicleAction(action)
    }

    public func scheduleSoftwareUpdate(offsetSeconds: Int32) async throws {
        var action = CarServer_VehicleAction()
        var update = CarServer_VehicleControlScheduleSoftwareUpdateAction()
        update.offsetSec = offsetSeconds
        action.vehicleControlScheduleSoftwareUpdateAction = update
        try await sendVehicleAction(action)
    }

    public func cancelSoftwareUpdate() async throws {
        var action = CarServer_VehicleAction()
        action.vehicleControlCancelSoftwareUpdateAction = CarServer_VehicleControlCancelSoftwareUpdateAction()
        try await sendVehicleAction(action)
    }

    public func setPinToDrive(enabled: Bool, pin: String) async throws {
        var action = CarServer_VehicleAction()
        var pinAction = CarServer_VehicleControlSetPinToDriveAction()
        pinAction.on = enabled
        pinAction.password = pin
        action.vehicleControlSetPinToDriveAction = pinAction
        try await sendVehicleAction(action)
    }

    public func resetPinToDrive() async throws {
        var action = CarServer_VehicleAction()
        action.vehicleControlResetPinToDriveAction = CarServer_VehicleControlResetPinToDriveAction()
        try await sendVehicleAction(action)
    }
}
