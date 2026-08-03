import Foundation
import Combine
import SwiftUI

/// Dashla-style dashboard preferences (UserDefaults-backed).
@MainActor
final class HUDSettings: ObservableObject {
    static let shared = HUDSettings()

    enum RefreshMode: String, CaseIterable, Identifiable {
        case low = "Düşük"
        case performance = "Performans"
        var id: String { rawValue }
        /// BLE poll interval seconds
        var bleInterval: TimeInterval { self == .performance ? 0.14 : 0.5 }
        /// Dash HTTP poll nanoseconds
        var dashNanos: UInt64 { self == .performance ? 200_000_000 : 900_000_000 }
    }

    enum SpeedStyle: String, CaseIterable, Identifiable {
        case classic = "Classic"
        case compact = "Compact"
        var id: String { rawValue }
    }

    enum SpeedColor: String, CaseIterable, Identifiable {
        case single = "Single"
        case multicolor = "Multicolor"
        var id: String { rawValue }
    }

    enum PowerStyle: String, CaseIterable, Identifiable {
        case top = "Top"
        case ring = "Ring"
        case off = "Off"
        var id: String { rawValue }
    }

    enum LiveLocation: String, CaseIterable, Identifiable {
        case top = "Top"
        case bottom = "Bottom"
        case off = "Off"
        var id: String { rawValue }
    }

    enum MapsProvider: String, CaseIterable, Identifiable {
        case apple = "Apple Maps"
        case google = "Google Maps"
        var id: String { rawValue }
    }

    enum MapTheme: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case light = "Light"
        case dark = "Dark"
        var id: String { rawValue }
    }

    @Published var refreshMode: RefreshMode {
        didSet { UserDefaults.standard.set(refreshMode.rawValue, forKey: "pulse_refresh_mode") }
    }
    @Published var speedStyle: SpeedStyle {
        didSet { UserDefaults.standard.set(speedStyle.rawValue, forKey: "pulse_speed_style") }
    }
    @Published var speedColor: SpeedColor {
        didSet { UserDefaults.standard.set(speedColor.rawValue, forKey: "pulse_speed_color") }
    }
    @Published var powerStyle: PowerStyle {
        didSet { UserDefaults.standard.set(powerStyle.rawValue, forKey: "pulse_power_style") }
    }
    @Published var liveLocation: LiveLocation {
        didSet { UserDefaults.standard.set(liveLocation.rawValue, forKey: "pulse_live_location") }
    }
    @Published var mapsProvider: MapsProvider {
        didSet { UserDefaults.standard.set(mapsProvider.rawValue, forKey: "pulse_maps_provider") }
    }
    @Published var autoZoom: Bool {
        didSet { UserDefaults.standard.set(autoZoom, forKey: "pulse_maps_auto_zoom") }
    }
    @Published var mapTheme: MapTheme {
        didSet { UserDefaults.standard.set(mapTheme.rawValue, forKey: "pulse_map_theme") }
    }
    @Published var gearMulticolor: Bool {
        didSet { UserDefaults.standard.set(gearMulticolor, forKey: "pulse_gear_multicolor") }
    }

    private init() {
        let d = UserDefaults.standard
        refreshMode = RefreshMode(rawValue: d.string(forKey: "pulse_refresh_mode") ?? "") ?? .performance
        speedStyle = SpeedStyle(rawValue: d.string(forKey: "pulse_speed_style") ?? "") ?? .classic
        speedColor = SpeedColor(rawValue: d.string(forKey: "pulse_speed_color") ?? "") ?? .multicolor
        powerStyle = PowerStyle(rawValue: d.string(forKey: "pulse_power_style") ?? "") ?? .ring
        liveLocation = LiveLocation(rawValue: d.string(forKey: "pulse_live_location") ?? "") ?? .bottom
        let storedProvider = d.string(forKey: "pulse_maps_provider") ?? ""
        // Migrate old short labels.
        switch storedProvider {
        case "Google", "Google Maps": mapsProvider = .google
        default: mapsProvider = .apple
        }
        autoZoom = d.object(forKey: "pulse_maps_auto_zoom") as? Bool ?? true
        mapTheme = MapTheme(rawValue: d.string(forKey: "pulse_map_theme") ?? "") ?? .dark
        gearMulticolor = d.object(forKey: "pulse_gear_multicolor") as? Bool ?? true
    }

    func gearColor(_ gear: String, active: Bool, ink: Color, dim: Color) -> Color {
        guard active else { return dim }
        guard gearMulticolor || speedColor == .multicolor else { return ink }
        switch gear {
        case "P": return Color(red: 0.95, green: 0.45, blue: 0.85)
        case "R": return Color(red: 1.0, green: 0.55, blue: 0.2)
        case "N": return Color(red: 0.35, green: 0.9, blue: 0.45)
        case "D": return Color(red: 0.35, green: 0.7, blue: 1.0)
        default: return ink
        }
    }
}
