import Foundation

struct VehicleState: Equatable {
    var speedKph: Double?
    var gear: GearPosition
    var batteryPercent: Int?
    var rangeKm: Double?
    var odometerKm: Double?
    var outsideTempC: Double?
    var tirePressure: TirePressure
    var locked: Bool?
    var sentryOn: Bool?
    var chargeStateLabel: String?
    var destination: String?
    var arrivalTime: Date?
    var energyAtArrivalPercent: Int?
    var distanceToDestinationKm: Double?
    var lastUpdated: Date?

    static let empty = VehicleState(
        speedKph: nil,
        gear: .park,
        batteryPercent: nil,
        rangeKm: nil,
        odometerKm: nil,
        outsideTempC: nil,
        tirePressure: .unknown,
        locked: nil,
        sentryOn: nil,
        chargeStateLabel: nil,
        destination: nil,
        arrivalTime: nil,
        energyAtArrivalPercent: nil,
        distanceToDestinationKm: nil,
        lastUpdated: nil
    )

    /// Preview / simulator sample matching a parked Model 3.
    static let preview = VehicleState(
        speedKph: 0,
        gear: .park,
        batteryPercent: 69,
        rangeKm: 331,
        odometerKm: 74_832,
        outsideTempC: 29,
        tirePressure: TirePressure(fl: 42.5, fr: 42.0, rl: 42.5, rr: 42.0),
        locked: true,
        sentryOn: false,
        chargeStateLabel: nil,
        destination: "Ertürk Sk. No:29",
        arrivalTime: nil,
        energyAtArrivalPercent: nil,
        distanceToDestinationKm: nil,
        lastUpdated: .now
    )
}

enum GearPosition: String, CaseIterable, Equatable {
    case park = "P"
    case reverse = "R"
    case neutral = "N"
    case drive = "D"

    var label: String { rawValue }
}

struct TirePressure: Equatable {
    var fl: Double?
    var fr: Double?
    var rl: Double?
    var rr: Double?

    static let unknown = TirePressure(fl: nil, fr: nil, rl: nil, rr: nil)

    func formatted(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.0f", value)
    }
}

enum ConnectionStatus: Equatable {
    case idle
    case scanning
    case connecting
    case connected
    case reconnecting
    case disconnected
    case error(String)

    var title: String {
        switch self {
        case .idle: return "Hazır"
        case .scanning: return "Taranıyor"
        case .connecting: return "Bağlanıyor"
        case .connected: return "Bağlı"
        case .reconnecting: return "Yeniden bağlan"
        case .disconnected: return "Bağlı değil"
        case .error: return "Hata"
        }
    }

    var isLive: Bool {
        if case .connected = self { return true }
        return false
    }
}

enum LeftPanelMode: String, CaseIterable, Identifiable {
    case vehicle
    case media
    case trip
    case controls

    var id: String { rawValue }
}
