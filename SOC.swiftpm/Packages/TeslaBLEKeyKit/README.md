# TeslaBLEKeyKit

A pure Swift library for communicating with Tesla vehicles over BLE (Bluetooth Low Energy). It implements the local BLE command protocol including universal-message session authentication and VCSEC commands — no Tesla Fleet API or network access required.

## Features

- **BLE Scanning** — discover nearby Tesla vehicles via `BLEScanner` with `AsyncStream` support
- **BLE Connection** — connect to a specific vehicle by VIN or VIN-free pairing via `BLEConnection`
- **VCSEC Protocol** — lock, unlock, trunk/frunk control, remote drive, and more
- **Vehicle Commands** — climate, charging, driving, media, sunroof, windows, sentry mode, and more via CarServer protocol
- **Vehicle Data** — query charge state, climate state, drive state, tire pressure, and more
- **Session Authentication** — P256 ECDH key agreement with AES-GCM / HMAC-SHA256
- **Key Management** — generate key pairs and add keys to the vehicle whitelist
- **Unified Logging** — structured logging via `os.Logger` with notification-based log forwarding
- **Async/Await** — modern structured concurrency throughout
- **Modular Architecture** — use only the modules you need (Core, Crypto, BLE, or all-in-one)

## Supported Platforms

| Platform | Minimum Version |
|----------|----------------|
| iOS | 16.0 |
| macOS | 13.0 |
| watchOS | 9.0 |

> **Note:** BLE scanning and connection require CoreBluetooth and Bluetooth LE capable hardware.

**Swift Compatibility:** 5.9, 5.10, 6.0

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/misakatao/TeslaBLEKeyKit.git", from: "0.1.0"),
]
```

Then add `"TeslaBLEKeyKit"` to your target's dependencies. This single import gives you access to all sub-modules.

If you only need specific functionality, you can depend on individual modules:

| Module | Contents |
|--------|----------|
| `TeslaBLEKeyKitCore` | Error types, data utilities, Protobuf definitions, logging, `VehicleConnector` protocol |
| `TeslaBLEKeyKitCrypto` | AES-128, AES-GCM, P-256 key management |
| `TeslaBLEKeyKitBLE` | BLE framing, scanning, CoreBluetooth connection |
| `TeslaBLEKeyKit` | Full library (re-exports all modules above) |

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'TeslaBLEKeyKit', '~> 0.1.0'
```

Then run `pod install`.

## Quick Start

### Scanning for Vehicles

```swift
import TeslaBLEKeyKit

let scanner = BLEScanner()

for await advertisement in scanner.scan() {
    print("Found Tesla: \(advertisement.localName)")
    print("  RSSI: \(advertisement.rssi)")
    print("  Connectable: \(advertisement.isConnectable)")
}

// Stop scanning when done
scanner.stop()
```

### Connecting and Sending Commands

```swift
import TeslaBLEKeyKit

// 1. Generate or load a private key
let privateKey = TeslaPrivateKey.generate()

// 2. Create a BLE connection (by VIN or VIN-free)
let connection = try BLEConnection(vin: "5YJ3E1EA0LF000000")
// Or connect without VIN (pairs with the nearest vehicle):
// let connection = try BLEConnection()
try await connection.connect()

// 3. Create a vehicle instance
let vehicle = try TeslaVehicle(connector: connection, privateKey: privateKey)
try await vehicle.connect()

// 4. Start a VCSEC session
try await vehicle.startVCSECSession()

// 5. Send commands
try await vehicle.wakeVehicle()
try await vehicle.unlock()
try await vehicle.lock()
try await vehicle.openTrunk()

// 6. Disconnect when done
vehicle.disconnect()
```

### Adding a Key to the Vehicle

```swift
let newKey = TeslaPrivateKey.generate()
try await vehicle.addKeyToWhitelist(
    publicKey: newKey.publicKey,
    role: .driver,
    formFactor: .iosDevice
)
```

### Key Persistence

```swift
let key = TeslaPrivateKey.generate()

// Save (choose any format)
let raw = key.rawRepresentation   // 32 bytes
let pem = key.pemRepresentation   // PEM string
let der = key.derRepresentation   // DER data

// Restore
let restored = try TeslaPrivateKey(rawRepresentation: raw)
```

## Available Commands

### VCSEC Commands

| Command | Method |
|---------|--------|
| Wake | `wakeVehicle()` |
| Unlock | `unlock()` |
| Lock | `lock()` |
| Open/Close Trunk | `openTrunk()` / `closeTrunk()` |
| Actuate Trunk | `actuateTrunk()` |
| Open Frunk | `openFrunk()` |
| Open/Close/Stop Tonneau | `openTonneau()` / `closeTonneau()` / `stopTonneau()` |
| Remote Drive | `remoteDrive()` |
| Auto Secure | `autoSecureVehicle()` |
| Vehicle Status | `vehicleStatus()` |
| Move Closure | `moveClosure(_:action:)` |
| Add Key | `addKeyToWhitelist(publicKey:role:formFactor:)` |
| Raw VCSEC | `sendRawVCSEC(payload:authenticated:)` |

### Climate

| Command | Method |
|---------|--------|
| Auto Climate On/Off | `setClimateAuto(enabled:)` |
| Max Preconditioning | `setPreconditioningMax(enabled:)` |
| Steering Wheel Heater | `setSteeringWheelHeater(enabled:)` |
| Set Temperature | `setTemperature(driverCelsius:passengerCelsius:)` |
| Bioweapon Mode | `setBioweaponMode(enabled:)` |
| Climate Keeper | `setClimateKeeper(mode:)` |
| Cabin Overheat Protection | `setCabinOverheatProtection(enabled:fanOnly:)` |

### Charging

| Command | Method |
|---------|--------|
| Set Charge Limit | `setChargeLimit(percent:)` |
| Start/Stop Charging | `startCharging()` / `stopCharging()` |
| Set Charging Amps | `setChargingAmps(_:)` |
| Open/Close Charge Port | `openChargePort()` / `closeChargePort()` |

### Driving

| Command | Method |
|---------|--------|
| Set Speed Limit | `setSpeedLimit(mph:)` |
| Activate/Deactivate Speed Limit | `activateSpeedLimit(pin:)` / `deactivateSpeedLimit(pin:)` |
| Clear Speed Limit Pin | `clearSpeedLimitPin(pin:)` |

### Vehicle Control

| Command | Method |
|---------|--------|
| Flash Lights | `flashLights()` |
| Honk Horn | `honkHorn()` |
| Sentry Mode | `setSentryMode(enabled:)` |
| Valet Mode | `setValetMode(enabled:password:)` |
| Reset Valet Pin | `resetValetPin()` |
| Sunroof | `controlSunroof(_:)` |
| Windows | `controlWindows(_:)` |
| Trigger Homelink | `triggerHomelink(latitude:longitude:)` |

### Media

| Command | Method |
|---------|--------|
| Toggle Playback | `mediaTogglePlayback()` |
| Next/Previous Track | `mediaNextTrack()` / `mediaPreviousTrack()` |
| Next/Previous Favorite | `mediaNextFavorite()` / `mediaPreviousFavorite()` |
| Adjust Volume | `mediaAdjustVolume(delta:)` |
| Set Volume | `mediaSetVolume(absolute:)` |

### Data & Misc

| Command | Method |
|---------|--------|
| Get Vehicle Data | `getVehicleData()` |
| Nearby Charging Sites | `getNearbyChargingSites(radius:count:)` |
| Set Vehicle Name | `setVehicleName(_:)` |
| Erase User Data | `eraseUserData(reason:)` |
| Low Power Mode | `setLowPowerMode(enabled:)` |

## Configuration

```swift
// Use built-in presets
let vehicle = try TeslaVehicle(
    connector: connection,
    privateKey: privateKey,
    configuration: .standard           // 12-byte nonce (default)
)

let vehicle = try TeslaVehicle(
    connector: connection,
    privateKey: privateKey,
    configuration: .fourByteNonceBLE   // 4-byte nonce for BLE variant
)

// Or customize
let config = TeslaVehicleConfiguration(
    nonceMode: .teslaBLE4Byte,
    commandTimeout: 10,
    sessionTimeout: 15
)
```

## Error Handling

All errors are represented by `TeslaError`, which conforms to `LocalizedError` and `Equatable`.

```swift
do {
    try await vehicle.unlock()
} catch let error as TeslaError {
    if error.isTemporary {
        // Safe to retry: vehicleBusy, scanTimedOut, certain protocolFault codes
    }
    if error.mayHaveSucceeded {
        // The command may have taken effect: timeout, protocolFault(0/25)
    }
    print(error.errorDescription ?? "Unknown error")
}
```

Use `shouldRetry(_:)` for automatic retry decisions:

```swift
if shouldRetry(error) {
    // Retry the operation
}
```

## Custom Connectors

You can implement the `VehicleConnector` protocol to provide your own transport layer (e.g., for testing or non-BLE transports):

```swift
class MockConnector: VehicleConnector {
    var vin: String { "TEST_VIN" }
    var retryInterval: TimeInterval { 1 }
    var allowedLatency: TimeInterval { 4 }
    var preferredAuthMethod: ConnectorAuthMethod { .aesGCM }

    func receiveMessages() -> AsyncStream<Data> { ... }
    func send(_ message: Data) async throws { ... }
    func close() { ... }
}
```

## Logging

TeslaBLEKeyKit uses Apple's unified logging system (`os.Logger`) for structured diagnostics across BLE, session, and command flows.

```swift
// Observe error-level and above logs via NotificationCenter
NotificationCenter.default.addObserver(
    forName: .teslaBLEKeyLog,
    object: nil,
    queue: .main
) { notification in
    let message = notification.userInfo?["message"] as? String ?? ""
    print("TeslaBLE: \(message)")
}
```

## Project Structure

```
Sources/
├── TeslaBLEKeyKitCore/       Core utilities, errors, logging, Protobuf types
├── TeslaBLEKeyKitCrypto/     AES-128, AES-GCM, P-256 key management
├── TeslaBLEKeyKitBLE/        BLE framing, scanning, connection
└── TeslaBLEKeyKit/           Session, dispatcher, vehicle commands
Example/
└── TeslaBLEKeyKitExample/    Xcode example project
```

## Running the Example

Open `Example/TeslaBLEKeyKitExample.xcodeproj` in Xcode, select a target device with Bluetooth support, and run.

## Testing

```bash
swift test
```

The test suite includes 192 tests across both Swift Testing and XCTest frameworks, covering cryptographic primitives, BLE framing, key management, error handling, and example usage patterns.

## License

MIT License. See [LICENSE](LICENSE) for details.
