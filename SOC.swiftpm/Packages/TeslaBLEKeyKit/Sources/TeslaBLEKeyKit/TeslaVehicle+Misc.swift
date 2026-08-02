import Foundation
#if !COCOAPODS
import TeslaBLEKeyKitCore
#endif

extension TeslaVehicle {
    public func setVehicleName(_ name: String) async throws {
        var action = CarServer_VehicleAction()
        var setName = CarServer_SetVehicleNameAction()
        setName.vehicleName = name
        action.setVehicleNameAction = setName
        try await sendVehicleAction(action)
    }

    public func eraseUserData(reason: String = "") async throws {
        var action = CarServer_VehicleAction()
        var erase = CarServer_EraseUserDataAction()
        erase.reason = reason
        action.eraseUserDataAction = erase
        try await sendVehicleAction(action)
    }

    public func setLowPowerMode(enabled: Bool) async throws {
        var action = CarServer_VehicleAction()
        var lowPower = CarServer_SetLowPowerModeAction()
        lowPower.lowPowerMode = enabled
        action.setLowPowerModeAction = lowPower
        try await sendVehicleAction(action)
    }
}
