import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Route: Equatable {
        case dashboard
        case beforeYouStart
        case pairVIN
        case waitingForKeyCard
        case settings
    }

    @Published var route: Route
    @Published var pairedVIN: String?
    @Published var unitSystem: UnitSystem = .metric

    let vehicleStore: VehicleStore
    let bleService: TeslaBLEService
    let mediaService: NowPlayingService
    let locationService: LocationService

    private var cancellables = Set<AnyCancellable>()

    init(
        vehicleStore: VehicleStore = .shared,
        bleService: TeslaBLEService? = nil,
        mediaService: NowPlayingService = .shared,
        locationService: LocationService = .shared
    ) {
        self.vehicleStore = vehicleStore
        self.mediaService = mediaService
        self.locationService = locationService

        let vin = vehicleStore.pairedVIN
        self.pairedVIN = vin
        self.route = vin == nil ? .beforeYouStart : .dashboard

        let service = bleService ?? TeslaBLEService(vehicleStore: vehicleStore)
        self.bleService = service

        if let vin {
            Task { await service.prepare(vin: vin) }
        }

        vehicleStore.$pairedVIN
            .receive(on: RunLoop.main)
            .sink { [weak self] newVIN in
                guard let self else { return }
                self.pairedVIN = newVIN
                if newVIN == nil, self.route == .dashboard {
                    self.route = .beforeYouStart
                }
            }
            .store(in: &cancellables)

        // Surface nested ObservableObject updates to SwiftUI.
        service.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        mediaService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        locationService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func beginPairing() {
        route = .pairVIN
    }

    func cancelPairing() {
        route = pairedVIN == nil ? .beforeYouStart : .dashboard
    }

    func completePairing(vin: String) {
        vehicleStore.savePairedVIN(vin)
        pairedVIN = vin
        route = .waitingForKeyCard
        Task { await bleService.prepare(vin: vin) }
    }

    func finishKeyCardStep() {
        route = .dashboard
        Task { await bleService.connect() }
    }

    func openSettings() {
        route = .settings
    }

    func closeSettings() {
        route = .dashboard
    }

    func unpair() async {
        await bleService.disconnect()
        vehicleStore.clearPairing()
        pairedVIN = nil
        route = .beforeYouStart
    }
}

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var speedLabel: String { self == .metric ? "km/h" : "mph" }
    var distanceLabel: String { self == .metric ? "km" : "mi" }
    var pressureLabel: String { self == .metric ? "psi" : "psi" }
}
