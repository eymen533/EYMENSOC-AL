import Foundation
import SwiftProtobuf
#if !COCOAPODS
import TeslaBLEKeyKitCore
#endif
#if !COCOAPODS
import TeslaBLEKeyKitCrypto
#endif

public struct TeslaVehicleConfiguration: Sendable, Equatable {
    public var nonceMode: AESGCMNonceMode
    public var commandTimeout: TimeInterval
    public var sessionTimeout: TimeInterval
    
    public init(
        nonceMode: AESGCMNonceMode = .standard12Byte,
        commandTimeout: TimeInterval = 10,
        sessionTimeout: TimeInterval = 15
    ) {
        self.nonceMode = nonceMode
        self.commandTimeout = commandTimeout
        self.sessionTimeout = sessionTimeout
    }
    
    public static let standard = TeslaVehicleConfiguration()
    public static let fourByteNonceBLE = TeslaVehicleConfiguration(nonceMode: .teslaBLE4Byte)
}

public enum TeslaClosure: Sendable, Equatable {
    case trunk
    case frunk
    case tonneau
    case chargePort
}

public final class TeslaVehicle {
    public static let defaultFlags = UInt32(1 << UniversalMessage_Flags.flagEncryptResponse.rawValue)
    
    public var flags: UInt32
    public let vin: String
    
    private let connector: VehicleConnector
    private let dispatcher: TeslaDispatcher
    private let configuration: TeslaVehicleConfiguration
    
    public init(
        connector: VehicleConnector,
        privateKey: TeslaPrivateKey?,
        configuration: TeslaVehicleConfiguration = .standard
    ) throws {
        self.connector = connector
        self.dispatcher = try TeslaDispatcher(
            connector: connector,
            privateKey: privateKey,
            nonceMode: configuration.nonceMode
        )
        self.configuration = configuration
        self.vin = connector.vin
        self.flags = Self.defaultFlags
    }
    
    public func connect() async throws {
        Log.info("TeslaVehicle connecting, VIN=\(vin)")
        dispatcher.start()
    }

    public func disconnect() {
        Log.info("TeslaVehicle disconnecting, VIN=\(vin)")
        dispatcher.stop()
        connector.close()
    }

    public func startInfotainmentSession() async throws {
        Log.info("Starting Infotainment session")
        try await dispatcher.startSession(
            domain: .infotainment,
            timeout: configuration.sessionTimeout
        )
    }

    @discardableResult
    public func sendVehicleAction(_ action: CarServer_VehicleAction) async throws -> CarServer_Response {
        var carAction = CarServer_Action()
        carAction.vehicleAction = action
        let bytes = try carAction.serializedData()
        return try await getInfotainmentResult(payload: bytes, auth: connector.preferredAuthMethod.internalAuthMethod)
    }

    private func getInfotainmentResult(
        payload: Data,
        auth: AuthMethod
    ) async throws -> CarServer_Response {
        while true {
            do {
                let receiver = try await getReceiver(
                    domain: .infotainment,
                    payload: payload,
                    auth: auth
                )
                defer { receiver.close() }
                return try await readInfotainmentResponse(receiver: receiver)
            } catch {
                guard shouldRetry(error) else {
                    throw error
                }
                Log.debug("Infotainment command retrying:", Log.errorSummary(error))
                try await Task.sleep(nanoseconds: UInt64(connector.retryInterval * 1_000_000_000))
            }
        }
    }

    private func readInfotainmentResponse(
        receiver: ResponseReceiver
    ) async throws -> CarServer_Response {
        try await withTimeout(seconds: configuration.commandTimeout) {
            for await message in receiver.messages() {
                return try carServerResponse(from: message)
            }
            throw TeslaError.notConnected
        }
    }

    public func startVCSECSession() async throws {
        Log.info("Starting VCSEC session")
        try await dispatcher.startSession(
            domain: .vehicleSecurity,
            timeout: configuration.sessionTimeout
        )
    }
    
    public func vehicleStatus() async throws -> VCSEC_VehicleStatus {
        let response = try await getVCSECInfo(.getStatus)
        guard case .vehicleStatus(let status)? = response.subMessage else {
            throw TeslaError.malformedResponse("VCSEC status response missing vehicleStatus")
        }
        return status
    }
    
    public func wakeVehicle() async throws {
        try await executeRKEAction(.rkeActionWakeVehicle)
    }
    
    public func unlock() async throws {
        try await executeRKEAction(.rkeActionUnlock)
    }
    
    public func lock() async throws {
        try await executeRKEAction(.rkeActionLock)
    }
    
    public func remoteDrive() async throws {
        try await executeRKEAction(.rkeActionRemoteDrive)
    }
    
    public func autoSecureVehicle() async throws {
        try await executeRKEAction(.rkeActionAutoSecureVehicle)
    }
    
    public func actuateTrunk() async throws {
        try await moveClosure(.trunk, action: .closureMoveTypeMove)
    }
    
    public func openTrunk() async throws {
        try await moveClosure(.trunk, action: .closureMoveTypeMove)
    }
    
    public func closeTrunk() async throws {
        try await moveClosure(.trunk, action: .closureMoveTypeClose)
    }
    
    public func openFrunk() async throws {
        try await moveClosure(.frunk, action: .closureMoveTypeMove)
    }
    
    public func openTonneau() async throws {
        try await moveClosure(.tonneau, action: .closureMoveTypeOpen)
    }
    
    public func closeTonneau() async throws {
        try await moveClosure(.tonneau, action: .closureMoveTypeClose)
    }
    
    public func stopTonneau() async throws {
        try await moveClosure(.tonneau, action: .closureMoveTypeStop)
    }
    
    public func moveClosure(_ closure: TeslaClosure, action: VCSEC_ClosureMoveType_E) async throws {
        Log.info("Moving closure: \(closure), action: \(action)")
        var request = VCSEC_ClosureMoveRequest()
        switch closure {
        case .trunk:
            request.rearTrunk = action
        case .frunk:
            request.frontTrunk = action
        case .tonneau:
            request.tonneau = action
        case .chargePort:
            request.chargePort = action
        }
        
        var payload = VCSEC_UnsignedMessage()
        payload.closureMoveRequest = request
        try await sendVCSECCommand(payload, auth: connector.preferredAuthMethod.internalAuthMethod) { response in
            if response.hasCommandStatus {
                return (false, nil)
            }
            return (true, nil)
        }
    }
    
    public func addKeyToWhitelist(
        publicKey: Data,
        role: Keys_Role = .driver,
        formFactor: VCSEC_KeyFormFactor = .iosDevice
    ) async throws {
        Log.info("Adding key to whitelist, role=\(role), formFactor=\(formFactor)")
        var permission = VCSEC_PermissionChange()
        permission.key.publicKeyRaw = publicKey
        permission.keyRole = role
        
        var operation = VCSEC_WhitelistOperation()
        operation.addKeyToWhitelistAndAddPermissions = permission
        operation.metadataForKey.keyFormFactor = formFactor
        
        var payload = VCSEC_UnsignedMessage()
        payload.whitelistOperation = operation
        try await sendVCSECCommand(payload, auth: connector.preferredAuthMethod.internalAuthMethod) { response in
            if case .commandStatus(let status)? = response.subMessage,
               case .whitelistOperationStatus(let whitelist)? = status.subMessage {
                let code = whitelist.whitelistOperationInformation.rawValue
                return (true, code == 0 ? nil : TeslaError.whitelistError(code))
            }
            return (false, nil)
        }
    }
    
    public func sendRawVCSEC(
        payload: Data,
        authenticated: Bool = true
    ) async throws -> VCSEC_FromVCSECMessage {
        let auth = authenticated ? connector.preferredAuthMethod.internalAuthMethod : .none
        return try await getVCSECResult(payload: payload, auth: auth) { _ in
            (true, nil)
        }
    }
    
    private func getVCSECInfo(_ requestType: VCSEC_InformationRequestType) async throws -> VCSEC_FromVCSECMessage {
        var request = VCSEC_InformationRequest()
        request.informationRequestType = requestType
        
        var payload = VCSEC_UnsignedMessage()
        payload.informationRequest = request
        
        let bytes = try payload.serializedData()
        return try await getVCSECResult(payload: bytes, auth: .none) { _ in
            (true, nil)
        }
    }
    
    private func executeRKEAction(_ action: VCSEC_RKEAction_E) async throws {
        Log.info("Executing RKE action: \(action)")
        var payload = VCSEC_UnsignedMessage()
        payload.rkeaction = action
        try await sendVCSECCommand(payload, auth: connector.preferredAuthMethod.internalAuthMethod) { response in
            if response.hasCommandStatus {
                return (false, nil)
            }
            return (true, nil)
        }
        Log.info("RKE action completed: \(action)")
    }
    
    private func sendVCSECCommand(
        _ payload: VCSEC_UnsignedMessage,
        auth: AuthMethod,
        done: @escaping (VCSEC_FromVCSECMessage) -> (Bool, Error?)
    ) async throws {
        let bytes = try payload.serializedData()
        _ = try await getVCSECResult(payload: bytes, auth: auth, done: done)
    }
    
    private func getVCSECResult(
        payload: Data,
        auth: AuthMethod,
        done: @escaping (VCSEC_FromVCSECMessage) -> (Bool, Error?)
    ) async throws -> VCSEC_FromVCSECMessage {
        while true {
            do {
                let receiver = try await getReceiver(
                    domain: .vehicleSecurity,
                    payload: payload,
                    auth: auth
                )
                defer { receiver.close() }
                return try await readUntil(receiver: receiver, done: done)
            } catch {
                guard shouldRetry(error) else {
                    throw error
                }
                Log.debug("VCSEC command retrying:", Log.errorSummary(error))
                try await Task.sleep(nanoseconds: UInt64(connector.retryInterval * 1_000_000_000))
            }
        }
    }
    
    private func readUntil(
        receiver: ResponseReceiver,
        done: @escaping (VCSEC_FromVCSECMessage) -> (Bool, Error?)
    ) async throws -> VCSEC_FromVCSECMessage {
        try await withTimeout(seconds: configuration.commandTimeout) {
            for await message in receiver.messages() {
                let response = try vcsecResponse(from: message)
                let result = done(response)
                if result.0 {
                    if let error = result.1 {
                        throw error
                    }
                    return response
                }
            }
            throw TeslaError.notConnected
        }
    }
    
    private func getReceiver(
        domain: TeslaDomain,
        payload: Data,
        auth: AuthMethod
    ) async throws -> ResponseReceiver {
        var message = UniversalMessage_RoutableMessage()
        message.toDestination.domain = domain
        message.protobufMessageAsBytes = payload
        message.flags = flags
        return try await dispatcher.send(
            message,
            auth: auth,
            timeout: configuration.commandTimeout
        )
    }
}
