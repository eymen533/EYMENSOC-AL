import Foundation
#if !COCOAPODS
import TeslaBLEKeyKitCore
#endif

extension TeslaVehicle {
    public func setChargeLimit(percent: Int32) async throws {
        var action = CarServer_VehicleAction()
        var limit = CarServer_ChargingSetLimitAction()
        limit.percent = percent
        action.chargingSetLimitAction = limit
        try await sendVehicleAction(action)
    }

    public func startCharging() async throws {
        var action = CarServer_VehicleAction()
        var start = CarServer_ChargingStartStopAction()
        start.chargingAction = .start(CarServer_Void())
        action.chargingStartStopAction = start
        try await sendVehicleAction(action)
    }

    public func stopCharging() async throws {
        var action = CarServer_VehicleAction()
        var stop = CarServer_ChargingStartStopAction()
        stop.chargingAction = .stop(CarServer_Void())
        action.chargingStartStopAction = stop
        try await sendVehicleAction(action)
    }

    public func setChargingAmps(_ amps: Int32) async throws {
        var action = CarServer_VehicleAction()
        var setAmps = CarServer_SetChargingAmpsAction()
        setAmps.chargingAmps = amps
        action.setChargingAmpsAction = setAmps
        try await sendVehicleAction(action)
    }

    public func openChargePort() async throws {
        var action = CarServer_VehicleAction()
        action.chargePortDoorOpen = CarServer_ChargePortDoorOpen()
        try await sendVehicleAction(action)
    }

    public func closeChargePort() async throws {
        var action = CarServer_VehicleAction()
        action.chargePortDoorClose = CarServer_ChargePortDoorClose()
        try await sendVehicleAction(action)
    }
}
