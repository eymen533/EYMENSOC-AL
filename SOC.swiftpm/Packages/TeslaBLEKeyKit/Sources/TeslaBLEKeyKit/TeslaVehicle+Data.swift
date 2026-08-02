import Foundation
#if !COCOAPODS
import TeslaBLEKeyKitCore
#endif

extension TeslaVehicle {
    public func getVehicleData() async throws -> CarServer_VehicleData {
        var action = CarServer_VehicleAction()
        var getData = CarServer_GetVehicleData()
        getData.getChargeState = CarServer_GetChargeState()
        getData.getClimateState = CarServer_GetClimateState()
        getData.getDriveState = CarServer_GetDriveState()
        getData.getLocationState = CarServer_GetLocationState()
        getData.getClosuresState = CarServer_GetClosuresState()
        getData.getChargeScheduleState = CarServer_GetChargeScheduleState()
        getData.getPreconditioningScheduleState = CarServer_GetPreconditioningScheduleState()
        getData.getTirePressureState = CarServer_GetTirePressureState()
        getData.getMediaState = CarServer_GetMediaState()
        getData.getMediaDetailState = CarServer_GetMediaDetailState()
        getData.getSoftwareUpdateState = CarServer_GetSoftwareUpdateState()
        getData.getParentalControlsState = CarServer_GetParentalControlsState()
        action.getVehicleData = getData
        let response = try await sendVehicleAction(action)
        guard case .vehicleData(let data) = response.responseMsg else {
            throw TeslaError.malformedResponse("expected vehicleData in response")
        }
        return data
    }

    public func getNearbyChargingSites(
        radius: Int32 = 200,
        count: Int32 = 25
    ) async throws -> CarServer_NearbyChargingSites {
        var action = CarServer_VehicleAction()
        var sites = CarServer_GetNearbyChargingSites()
        sites.radius = radius
        sites.count = count
        sites.includeMetaData = true
        action.getNearbyChargingSites = sites
        let response = try await sendVehicleAction(action)
        guard case .getNearbyChargingSites(let result) = response.responseMsg else {
            throw TeslaError.malformedResponse("expected nearbyChargingSites in response")
        }
        return result
    }

    public func ping() async throws -> CarServer_Ping {
        var action = CarServer_VehicleAction()
        var p = CarServer_Ping()
        p.pingID = 1
        action.ping = p
        let response = try await sendVehicleAction(action)
        guard case .ping(let result) = response.responseMsg else {
            throw TeslaError.malformedResponse("expected ping in response")
        }
        return result
    }
}
