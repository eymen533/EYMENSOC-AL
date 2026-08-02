import Foundation

#if canImport(TeslaBLEKeyKit)
import TeslaBLEKeyKit
#endif

enum VehicleStateMapper {
    #if canImport(TeslaBLEKeyKit)
    static func map(_ data: CarServer_VehicleData) -> VehicleState {
        var state = VehicleState.empty

        if data.hasChargeState {
            let charge = data.chargeState
            if charge.batteryLevel > 0 {
                state.batteryPercent = Int(charge.batteryLevel)
            }
            let rangeMiles = max(charge.estBatteryRange, charge.batteryRange)
            if rangeMiles > 0 {
                state.rangeKm = Double(rangeMiles) * 1.60934
            }
        }

        if data.hasDriveState {
            let drive = data.driveState
            if case .speedFloat(let value)? = drive.optionalSpeedFloat {
                state.speedKph = Double(value) * 1.60934
            } else if case .speed(let value)? = drive.optionalSpeed {
                state.speedKph = Double(value) * 1.60934
            } else {
                state.speedKph = 0
            }

            if case .odometerInHundredthsOfAMile(let value)? = drive.optionalOdometerInHundredthsOfAMile {
                let miles = Double(value) / 100.0
                state.odometerKm = miles * 1.60934
            }

            state.gear = mapShift(drive.shiftState)

            if case .activeRouteDestination(let value)? = drive.optionalActiveRouteDestination, !value.isEmpty {
                state.destination = value
            }
            if case .activeRouteMinutesToArrival(let minutes)? = drive.optionalActiveRouteMinutesToArrival, minutes > 0 {
                state.arrivalTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
            }
            if case .activeRouteEnergyAtArrival(let energy)? = drive.optionalActiveRouteEnergyAtArrival, energy > 0 {
                state.energyAtArrivalPercent = Int(energy.rounded())
            }
            if case .activeRouteMilesToArrival(let miles)? = drive.optionalActiveRouteMilesToArrival, miles > 0 {
                state.distanceToDestinationKm = Double(miles) * 1.60934
            }
        }

        if data.hasClimateState {
            state.outsideTempC = Double(data.climateState.outsideTempCelsius)
        }

        if data.hasTirePressureState {
            let tpms = data.tirePressureState
            state.tirePressure = TirePressure(
                fl: barToPsi(optional: tpms.optionalTpmsPressureFl),
                fr: barToPsi(optional: tpms.optionalTpmsPressureFr),
                rl: barToPsi(optional: tpms.optionalTpmsPressureRl),
                rr: barToPsi(optional: tpms.optionalTpmsPressureRr)
            )
        }

        if data.hasClosuresState {
            state.locked = data.closuresState.locked
            if data.closuresState.hasSentryModeState {
                switch data.closuresState.sentryModeState.type {
                case .some(.off(_)), .none:
                    state.sentryOn = false
                default:
                    state.sentryOn = true
                }
            }
        }

        state.lastUpdated = .now
        return state
    }

    private static func mapShift(_ shift: CarServer_ShiftState) -> GearPosition {
        switch shift.type {
        case .some(.r(_)): return .reverse
        case .some(.n(_)): return .neutral
        case .some(.d(_)): return .drive
        case .some(.p(_)), .some(.invalid(_)), .some(.sna(_)), .none: return .park
        }
    }

    private static func barToPsi(optional value: CarServer_TirePressureState.OneOf_OptionalTpmsPressureFl?) -> Double? {
        if case .tpmsPressureFl(let bar)? = value, bar > 0 { return Double(bar) * 14.5038 }
        return nil
    }

    private static func barToPsi(optional value: CarServer_TirePressureState.OneOf_OptionalTpmsPressureFr?) -> Double? {
        if case .tpmsPressureFr(let bar)? = value, bar > 0 { return Double(bar) * 14.5038 }
        return nil
    }

    private static func barToPsi(optional value: CarServer_TirePressureState.OneOf_OptionalTpmsPressureRl?) -> Double? {
        if case .tpmsPressureRl(let bar)? = value, bar > 0 { return Double(bar) * 14.5038 }
        return nil
    }

    private static func barToPsi(optional value: CarServer_TirePressureState.OneOf_OptionalTpmsPressureRr?) -> Double? {
        if case .tpmsPressureRr(let bar)? = value, bar > 0 { return Double(bar) * 14.5038 }
        return nil
    }
    #endif

    static func formatSpeed(_ kph: Double?, unit: UnitSystem) -> String {
        guard let kph else { return "0" }
        let value = unit == .metric ? kph : kph / 1.60934
        return String(Int(value.rounded()))
    }

    static func formatDistance(_ km: Double?, unit: UnitSystem) -> String {
        guard let km else { return "--" }
        let value = unit == .metric ? km : km / 1.60934
        return String(Int(value.rounded()))
    }

    static func formatTemp(_ celsius: Double?) -> String {
        guard let celsius else { return "--°C" }
        return "\(Int(celsius.rounded()))°C"
    }

    static func formatBattery(_ percent: Int?, rangeKm: Double?, unit: UnitSystem) -> String {
        let p = percent.map(String.init) ?? "--"
        let r = formatDistance(rangeKm, unit: unit)
        return "\(p)% / \(r)\(unit.distanceLabel)"
    }

    static func formatOdometer(_ km: Double?, unit: UnitSystem) -> String {
        let value = formatDistance(km, unit: unit)
        return "ODO \(value)\(unit.distanceLabel)"
    }
}
