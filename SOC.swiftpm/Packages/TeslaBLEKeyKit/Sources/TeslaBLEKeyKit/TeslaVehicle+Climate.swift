import Foundation
#if !COCOAPODS
import TeslaBLEKeyKitCore
#endif

extension TeslaVehicle {
    public func setClimateAuto(enabled: Bool) async throws {
        var action = CarServer_VehicleAction()
        var hvac = CarServer_HvacAutoAction()
        hvac.powerOn = enabled
        action.hvacAutoAction = hvac
        try await sendVehicleAction(action)
    }

    public func setPreconditioningMax(enabled: Bool) async throws {
        var action = CarServer_VehicleAction()
        var precon = CarServer_HvacSetPreconditioningMaxAction()
        precon.on = enabled
        action.hvacSetPreconditioningMaxAction = precon
        try await sendVehicleAction(action)
    }

    public func setSteeringWheelHeater(enabled: Bool) async throws {
        var action = CarServer_VehicleAction()
        var heater = CarServer_HvacSteeringWheelHeaterAction()
        heater.powerOn = enabled
        action.hvacSteeringWheelHeaterAction = heater
        try await sendVehicleAction(action)
    }

    public func setTemperature(driverCelsius: Float, passengerCelsius: Float) async throws {
        var action = CarServer_VehicleAction()
        var temp = CarServer_HvacTemperatureAdjustmentAction()
        temp.driverTempCelsius = driverCelsius
        temp.passengerTempCelsius = passengerCelsius
        action.hvacTemperatureAdjustmentAction = temp
        try await sendVehicleAction(action)
    }

    public func setBioweaponMode(enabled: Bool) async throws {
        var action = CarServer_VehicleAction()
        var bio = CarServer_HvacBioweaponModeAction()
        bio.on = enabled
        action.hvacBioweaponModeAction = bio
        try await sendVehicleAction(action)
    }

    public func setClimateKeeper(mode: CarServer_HvacClimateKeeperAction.ClimateKeeperAction_E) async throws {
        var action = CarServer_VehicleAction()
        var keeper = CarServer_HvacClimateKeeperAction()
        keeper.climateKeeperAction = mode
        action.hvacClimateKeeperAction = keeper
        try await sendVehicleAction(action)
    }

    public func setCabinOverheatProtection(enabled: Bool, fanOnly: Bool = false) async throws {
        var action = CarServer_VehicleAction()
        var cop = CarServer_SetCabinOverheatProtectionAction()
        cop.on = enabled
        cop.fanOnly = fanOnly
        action.setCabinOverheatProtectionAction = cop
        try await sendVehicleAction(action)
    }
}
