import Foundation
#if !COCOAPODS
import TeslaBLEKeyKitCore
#endif

extension TeslaVehicle {
    public func setSpeedLimit(mph: Double) async throws {
        var action = CarServer_VehicleAction()
        var limit = CarServer_DrivingSetSpeedLimitAction()
        limit.limitMph = mph
        action.drivingSetSpeedLimitAction = limit
        try await sendVehicleAction(action)
    }

    public func activateSpeedLimit(pin: String) async throws {
        var action = CarServer_VehicleAction()
        var limit = CarServer_DrivingSpeedLimitAction()
        limit.activate = true
        limit.pin = pin
        action.drivingSpeedLimitAction = limit
        try await sendVehicleAction(action)
    }

    public func deactivateSpeedLimit(pin: String) async throws {
        var action = CarServer_VehicleAction()
        var limit = CarServer_DrivingSpeedLimitAction()
        limit.activate = false
        limit.pin = pin
        action.drivingSpeedLimitAction = limit
        try await sendVehicleAction(action)
    }

    public func clearSpeedLimitPin(pin: String) async throws {
        var action = CarServer_VehicleAction()
        var clear = CarServer_DrivingClearSpeedLimitPinAction()
        clear.pin = pin
        action.drivingClearSpeedLimitPinAction = clear
        try await sendVehicleAction(action)
    }
}
