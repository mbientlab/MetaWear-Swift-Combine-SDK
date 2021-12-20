// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import MetaWearCpp
import Combine


/// Each MetaWear object corresponds a physical MetaWear board. This SDK
/// wraps type-safe Swift methods and Combine publishers around C/C++ functions
/// and CoreBluetooth APIs so you can get started quickly.
///
/// Most methods in this SDK are async `Combine` operators that extend
/// publishers with an output of `MetaWear`, which include:
/// - ``MetaWear/MetaWear/publish()``
/// - ``MetaWear/MetaWear/publishWhenConnected()``
/// - ``MetaWear/MetaWear/publishWhenDisconnected()``
///
/// You can find  operators via code completion or in the SDK's
/// `Combine` directory. (Sadly, Xcode 13.0's documentation
/// browser does not show extensions to out-of-module types.
///
/// Example 1. Read battery percentage remaining if connected when called.
/// ```swift
/// metawear
///     .publishIfConnected()
///     .read(.batteryLife)
///     .sink(receiveCompletion: {
///         switch $0 {
///             case .error(let error):   // Setup error
///             case .finished:           // Disconnected by request
///         }
///     }, receiveValue: { [weak self] value in {
///         self?.battery = value         // Connected & read
///     })
/// ```
///
/// Example 2. Stream data once connected the first time.
/// ```swift
/// let sensor: MWStreamable = .ambientLight(
///     rate: .ms1000,
///     gain: .x1,
///     integrationTime: .ms100
/// )
/// let stream = metawear
///     .publishWhenConnected()
///     .first()
///     .stream(sensor)
///     .sink { [weak self] value in
///         self?.lux = value
///     }
///
/// metawear.connect() // Kickoff connection
/// stream.cancel()    // Stop stream
/// ```
///
/// Example 3. Mix C++ with Combine in a recorded macro that clears logs on boot.
/// ```swift
/// let recordMacro = metawear
///     .publish()
///     .macro(executeOnBoot: true) { mw in
///         mw.flatMap { mw in
///             mbl_mw_logging_clear_entries(mw.board)
///             return mw
///         }
///     }
///     .sink { [weak self] macroIdentifier in
///         self?.macroID = macroIdentifier
///     }
/// ```
///
/// - Tip: Only use the serial ``bleQueue`` to place calls into the MetaWear C++ library.
/// All SDK publishers subscribe and output on the `bleQueue` unless stated.
/// Beware that a Combine operator like `.prefix(untilOutputFrom:)`
/// will switch cancellation and receipt to the exogenous publisher.
///
public class MetaWear: NSObject {

    // MARK: - References

    /// To prevent crashes, use this queue for all MetaWearCpp library calls.
    /// All SDK publishers subscribe and return on this queue unless stated.
    ///
    public var bleQueue: DispatchQueue { scanner.bleQueue }

    /// This device's CoreBluetooth object
    ///
    public let peripheral: CBPeripheral

    /// Scanner that discovered this device
    ///
    public unowned let scanner: MetaWearScanner

    /// Receives device activity
    ///
    public weak var logDelegate: MWConsoleLoggerDelegate?

    /// Pass to MetaWear C++ functions
    ///
    public private(set) var board: MWBoard!


    // MARK: - Connection State

    /// Whether advertised or discovered in recovery (MetaBoot) mode. KVO enabled.
    ///
    @objc dynamic public private(set) var isMetaBoot = false

    /// Stream of connecting, connected (and with C++ library setup), disconnecting, and disconnected events.
    ///
    public let connectionStatePublisher: AnyPublisher<CBPeripheralState, Never>

    /// Current connection state. Connected indicates a BLE connection and an initialized MetaWear C++ library.
    ///
    public var connectionState: CBPeripheralState { _connectionStateSubject.value }


    // MARK: - Signal (refreshed by `MetaWearScanner` activity)

    /// Last signal strength indicator received. Updates while `MetaWearScanner` or an rssi Publisher is active, plus when you call `updateRSSI()`.
    ///
    public var rssi: Int { _rssi.value }

    /// Most recent RSSI, as pushed from an active `MetaWearScanner` or from `CBPeripheralDelegate` about every 5 seconds by automatic calls to `updateRSSI()` (only while connected). -100  can indicate disconnection.
    ///
    public private(set) lazy var rssiPublisher: AnyPublisher<Int, Never> = _makeRSSIPublisher()

    /// Average of the last 5 seconds of signal strength, as pushed from an active `MetaWearScanner` or from `CBPeripheralDelegate` about every 5 seconds by automatic calls to `updateRSSI()`. -100 can indicate disconnection.
    ///
    public private(set) lazy var rssiMovingAveragePublisher: AnyPublisher<Int,Never> = _makeRSSIAveragePublisher()

    /// Most recent signal strength and advertisement packet data, while the `MetaWearScanner` is active.
    ///
    public let advertisementDataPublisher: AnyPublisher<(rssi: Int, advertisementData: [String:Any]), Never>

    /// Last advertisement packet data received.
    ///
    public var advertisementData: [String : Any] {
        get { Self._adQueue.sync { _adData } }
    }


    // MARK: - Device Identity

    /// MAC address, model, serial, firmware, hardware details. **Populated after connection, but the MAC address may be available immediately for remembered devices.**
    ///
    /// To maximize privacy, Apple obfuscates MAC addresses by replacing them with an auto-generated `UUID`. While stable locally, that id differs between a user's phones and computers. The MAC address exposed here enables recognizing devices across computers.
    ///
    public internal(set) var info: MetaWear.DeviceInformation

    /// Local machine's unique CoreBluetooth identifier for this device.
    ///
    public var localBluetoothID: CBPeripheralIdentifier { peripheral.identifier }

    /// Latest advertised name, which may might be cached on iOS. We recommend storing names in shared metadata, for example via `MetaWearSyncStore` iCloud user defaults sync.
    ///
    @objc dynamic public var name: String {
        return Self._adQueue.sync {
            let adName = _adData[CBAdvertisementDataLocalNameKey] as? String
            return adName ?? peripheral.name ?? Self.defaultName
        }
    }
    /// "MetaWear"
    public static let defaultName = "MetaWear"

    /// Validate a candidate rename of this MetaWear device.
    /// - Parameter proposed: desired new name
    /// - Returns: Validity of the new name
    ///
    public static func isNameValid(_ proposed: String) -> Bool {
        if proposed.isEmpty { return false }
        guard proposed.unicodeScalars.allSatisfy({ Self._validNameCharacters.contains($0) }),
              let encoded = proposed.data(using: .ascii)
        else { return false }
        return encoded.count <= Self._maxNameLength
    }
    public static let _maxNameLength = 26
    public static let _validNameCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_- ")

    /// Builds a dictionary of the board's sensors and specifics on its sensors' exact hardware. Useful when managing a MetaWear fleet with differing capabilities. (Requires connection.)
    ///
    /// - Returns: When connected, a dictionary where keys are available sensors and values are additional details on those sensors's hardware
    ///
    public func describeModules() -> MWPublisher<[MWModules.ID:MWModules]> {
        self.publishWhenConnected()
            .first()
            .map { MWModules.detect(in: $0.board) }
            .mapToMWError()
            .erase(subscribeOn: self.bleQueue)
    }


    // MARK: - Internal Properties

    /// When executing a test suite serially using a shared scanner against the same device, beware that MetaWear device instances are shared between your tests. You may need to set this to zero for certain tests where you are evaluating connection and disconnection behavior from a disconnected starting state. This is incremented by disconnect calls to interrupt an ongoing or the next scheduled connect request.
    public var _connectInterrupts: Int = 0

    // Delegate responses to async pipelines in setup/operation
    fileprivate var _setupMacToken: AnyCancellable? = nil
    fileprivate var _connectionStateSubject = CurrentValueSubject<CBPeripheralState,Never>(.disconnected)
    fileprivate var _connectSubjects: [PassthroughSubject<MetaWear, MWError>] = []
    fileprivate var _disconnectSubjects: [PassthroughSubject<MetaWear, MWError>] = []
    internal var _readCharacteristicSubjects: [CBCharacteristic: [PassthroughSubject<Data, MWError>]] = [:]
    fileprivate var _rssi: CurrentValueSubject<Int,Never> = .init(-100)

    // CBCharacteristics discovery + device setup
    fileprivate var _gattCharMap: [MblMwGattChar: CBCharacteristic] = [:]
    fileprivate var _serviceCount = 0
    fileprivate var _subsDiscovery = Set<AnyCancellable>()

    // Writes
    fileprivate var _commandCount = 0
    fileprivate var _writeQueue: [(data: Data, characteristic: CBCharacteristic, type: CBCharacteristicWriteType)] = []

    // MblMwBtleConnection callbacks for read/writeGattChar, _enableNotifications, and _onDisconnect functions
    fileprivate var _onDisconnectCallback: MblMwFnVoidVoidPtrInt?
    fileprivate var _onReadCallbacks: [CBCharacteristic: MblMwFnIntVoidPtrArray] = [:]
    fileprivate var _onDataCallbacks: [CBCharacteristic: MblMwFnIntVoidPtrArray] = [:]
    fileprivate var _subscribeCompleteCallbacks: [CBCharacteristic: MblMwFnVoidVoidPtrInt] = [:]

    /// Read/set from advertisement queue `Self.adQueue`
    fileprivate static let _adQueue = DispatchQueue(label: "com.mbientlab.adQueue")
    fileprivate var _rssiHistory: CurrentValueSubject<[(Date, Double)],Never> = .init([])
    fileprivate var _adData: [String : Any] = [:]
    fileprivate let _adReceivedSubject = CurrentValueSubject<(rssi: Int, advertisementData: [String:Any]), Never>( (rssi: -100, advertisementData: [String:Any]()) )
    fileprivate let _refreshTimer: AnyPublisher<Date,Never>
    fileprivate var _refreshables = [String:AnyCancellable]()
    fileprivate var _rssiRefreshSources = 0

    /// Please use ``MetaWearScanner`` to initialize MetaWears properly.
    /// To subclass the scanner, you may need to use this initializer.
    ///
    /// - Parameters:
    ///   - peripheral: Discovered `CBPeripheral`
    ///   - scanner: Scanner that discovered the peripheral
    ///   - mac: MAC address if known
    ///
    public init(peripheral: CBPeripheral,
                scanner: MetaWearScanner,
                mac: MACAddress? = nil) {
        self.peripheral = peripheral
        self.scanner = scanner
        self._refreshTimer = Self._makeFiveSecondRefresher(scanner.bleQueue)

        self.connectionStatePublisher = _connectionStateSubject.erase(subscribeOn: scanner.bleQueue)

        self.advertisementDataPublisher = self._adReceivedSubject
            .subscribe(on: Self._adQueue)
            .receive(on: scanner.bleQueue)
            .share()
            .eraseToAnyPublisher()

        // Populate MAC if known
        self.info = .init(mac: mac ?? UserDefaults.MetaWear.getMAC(for: peripheral.identifier))

        super.init()
        self.peripheral.delegate = self
        var connection = MblMwBtleConnection(
            context: bridge(obj: self),
            write_gatt_char: _writeGattChar,
            read_gatt_char: _readGattChar,
            enable_notifications: _enableNotifications,
            on_disconnect: _onDisconnect)
        self.board = mbl_mw_metawearboard_create(&connection)
        mbl_mw_metawearboard_set_time_for_response(self.board, 0)
    }
}

// MARK: - Public API (Connection Process)

public extension MetaWear {

    /// Connect to this MetaWear and, if needed, initializes the C++ library.
    ///
    /// Enqueues a connection request to the parent MetaWearScanner.
    /// For connection state changes, subscribe to `connectionState` or
    /// use the `connect() -> MWPublisher` variant.
    ///
    func connect() {
        bleQueue.async { [weak self] in

            // Only if not connected/connecting
            guard let self = self, self.connectionState != .connected else { return }

            // Cancel attempt if a disconnect request was received very recently
            guard self._connectInterrupts == 0 else {
                self._connectInterrupts = 0
                return
            }

            self.scanner.connect(self)
            self._connectionStateSubject.send(.connecting)
        }
    }

    /// Connects to this MetaWear, initializes the C++ library if needed,
    /// and publishes this MetaWear if successful or an error upon failure.
    ///
    /// This publisher enqueues a connection request to the
    /// scanner that discovered it. It behaves as follows:
    /// - on connection (or if already connected), sends a reference to self
    /// - on disconnect, completes without error
    /// - on a setup fault, completes with error
    /// - if you cancel or complete, disconnects the device
    /// - subscribes and sends on the ``bleQueue``
    ///
    /// Internally, this is an erased `PassthroughSubject`
    /// that is cached for `CBPeripheralDelegate` methods
    /// to call as setup progresses.
    ///
    /// - Returns: On the ``bleQueue`` an error, device reference (success), or completion on error-less disconnect
    ///
    func connectPublisher() -> MWPublisher<MetaWear> {
        MetaWear._buildConnectPublisher(self, self.connectionState == .connected)
            .handleEvents(receiveCancel: { [weak self] in
                self?.disconnect()
            })
            .share()
            .erase(subscribeOn: bleQueue)
    }

    /// Cancels a current connection, an ongoing connection attempt, or the next connection attempt.
    /// This method is idempotent (i.e., only the next connection attempt is cancelled).
    ///
    func disconnect() {
        bleQueue.async { [self] in
            let state = _connectionStateSubject.value
            self._connectionStateSubject.send(state == .disconnected ? .disconnected : .disconnecting)

            /// A connect request might come in ahead of a response by the scanner
            if self._connectSubjects.isEmpty && self._disconnectSubjects.isEmpty && state != .connected {
                _connectInterrupts += 1

            } else {
                scanner.cancelConnection(self)
                _connectInterrupts = 0
            }
        }
    }

    /// Remove this device from the local persistent table loaded by ``MetaWearScanner``.
    ///
    func forget() {
        UserDefaults.MetaWear.forgetLocalDevice(localBluetoothID)
        if self.connectionState == .connected { disconnect() }
    }

    /// Add this device to a local persisted table loaded by ``MetaWearScanner``.
    /// MetaWears are automatically added to this list upon connection.
    ///
    func remember() {
        guard info.mac.isEmpty == false else {
            connect() // Stores itself
            return
        }
        UserDefaults.MetaWear.rememberLocalDevice(localBluetoothID, info.mac)
    }
}


// MARK - Public API (Publishers to Kickoff Reads/Writes/Logs/Streams of Board Signals)

public extension MetaWear {

    /// Publishes this MetaWear once, regardless of connection state.
    ///
    func publish() -> MWPublisher<MetaWear> {
        Just(self)
            .setFailureType(to: MWError.self)
            .erase(subscribeOn: bleQueue)
    }

    /// Publishes if connected and setup at start, failing if not.
    ///
    func publishIfConnected() -> MWPublisher<MetaWear> {
        connectionState == .connected
        ? Just(self)
            .setFailureType(to: MWError.self)
            .erase(subscribeOn: bleQueue)
        : Fail(
            outputType: MetaWear.self,
            failure: MWError.operationFailed(
                "Connected MetaWear required. Currently: \(peripheral.state.debugDescription)"
            ))
            .erase(subscribeOn: bleQueue)
    }

    /// Publishes after connection and setup.
    ///
    func publishWhenConnected() -> AnyPublisher<MetaWear,Never> {
        _connectionStateSubject
            .compactMap { $0 == .connected ? self : nil }
            .subscribe(on: bleQueue)
            .eraseToAnyPublisher()
    }

    /// Publishes after disconnection.
    ///
    func publishWhenDisconnected() -> AnyPublisher<MetaWear,Never> {
        _connectionStateSubject
            .compactMap { $0 == .disconnected ? self : nil }
            .subscribe(on: bleQueue)
            .eraseToAnyPublisher()
    }

}


// MARK: - Public API (Signal Strength)

public extension MetaWear {

    /// Manually refreshes the peripheral's RSSI if connected.
    ///
    /// The value received as `CBPeripheralDelegate` is published through `rssiPublisher` or `rssiMovingAveragePublisher`. When you subscribe to those publishers, if the `MetaWearScanner` that discovered this device is not set to regularly update signal strength, it will use a timer to automatically call this function every 5 seconds.
    ///
    func updateRSSI() {
        peripheral.readRSSI()
    }
}


// MARK: - Public API (Reconnection to Known Devices)

public extension MetaWear {

    /// Before reconnecting to a device, restores data for C++ library by deserializing data you previously saved to the `uniqueURL`. You are responsible for writing data.
    ///
    func stateLoadFromUniqueURL() {
        if let data = try? Data(contentsOf: uniqueURL()) {
            stateDeserialize([UInt8](data))
        }
    }

    /// Dump all MetaWearC++ library state (prior to disconnection).
    ///
    func stateSerialize() -> [UInt8] {
        var count: UInt32 = 0
        let start = mbl_mw_metawearboard_serialize(board, &count)
        let data = Array(UnsafeBufferPointer(start: start, count: Int(count)))
        mbl_mw_memory_free(start)
        return data
    }

    /// Restore MetaWearC++ library state, must be called before `connectAndSetup()`.
    ///
    func stateDeserialize(_ _data: [UInt8]) {
        var data = _data
        mbl_mw_metawearboard_deserialize(board, &data, UInt32(data.count))
    }

    /// Creates a file name unique to this device, based on its `CBPeripheral` identifier UUID. The returned URL is inside the user's Application Support directory, within a subfolder: `com.mbientlab.devices`.
    ///
    func uniqueURL() -> URL {
        var url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.mbientlab.devices", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        url.appendPathComponent(peripheral.identifier.uuidString + ".file")
        return url
    }
}

// ########################################################### //
//                        END OF PUBLIC API                    //
// ########################################################### //

// MARK: - Internals - Conformance to `CBPeripheralDelegate` for device setup

extension MetaWear: CBPeripheralDelegate {

    // Device setup step 1
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            _invokeConnectionHandlers(error: error!, cancelled: false)
            disconnect()
            return
        }

        guard _connectInterrupts == 0 else {
            _invokeConnectionHandlers(error: nil, cancelled: true)
            _invokeDisconnectionHandlers(error: nil)
            return
        }

        _gattCharMap = [:]
        _serviceCount = 0
        for service in services {
            switch service.uuid {
                case .metaWearService:
                    isMetaBoot = false
                    peripheral.discoverCharacteristics([
                        .metaWearCommand,
                        .metaWearNotification
                    ], for: service)

                case .batteryService:
                    peripheral.discoverCharacteristics([
                        .batteryLife
                    ], for: service)

                case .disService:
                    peripheral.discoverCharacteristics([
                        .disManufacturerName,
                        .disSerialNumber,
                        .disHardwareRev,
                        .disFirmwareRev,
                        .disModelNumber
                    ], for: service)

                case .metaWearDfuService:
                    // Expected service, but we don't need to discover its characteristics
                    isMetaBoot = true

                default:
                    let error = MWError.operationFailed("MetaWear device contained an unexpected BLE service. Please try connection again.")
                    self._invokeConnectionHandlers(error: error, cancelled: false)
                    self._invokeDisconnectionHandlers(error: error)
                    self.disconnect()
                    break // Don't evaluate other services
            }
        }
    }

    // Device setup step 2
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            _invokeConnectionHandlers(error: error!, cancelled: false)
            disconnect()
            return
        }

        guard isMetaBoot == false else {
            _didDiscoverCharacteristicsForMetaBoot()
            return
        }

        guard _connectInterrupts == 0 else {
            _invokeConnectionHandlers(error: nil, cancelled: true)
            _invokeDisconnectionHandlers(error: nil)
            return
        }

        _serviceCount += 1
        guard _serviceCount == 3 else { return }

        _setupCppSDK_start()
    }

    // Responses to RSSI requests
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        _updateRSSIValues(RSSI: error == nil ? RSSI : -100)
    }

    // Responses to readValue requests.
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        logDelegate?._didUpdateValueFor(characteristic: characteristic, error: error)
        guard error == nil, let data = characteristic.value, data.count > 0 else { return }

        if let onRead = _onReadCallbacks[characteristic] {
            data.withUnsafeBytes { rawBufferPointer -> Void in
                let unsafeBufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
                let unsafePointer = unsafeBufferPointer.baseAddress!
                let _ = onRead(UnsafeRawPointer(board), unsafePointer, UInt8(data.count))
            }
            _onReadCallbacks.removeValue(forKey: characteristic)
        }

        if let onData = _onDataCallbacks[characteristic] {
            data.withUnsafeBytes { rawBufferPointer -> Void in
                let unsafeBufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
                let unsafePointer = unsafeBufferPointer.baseAddress!
                let _ = onData(UnsafeRawPointer(board), unsafePointer, UInt8(data.count))
            }
        }

        if let promises = _readCharacteristicSubjects.removeValue(forKey: characteristic) {
            promises.forEach {
                $0.send(data)
                $0.send(completion: .finished)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {

        logDelegate?.logWith(.info, message: "didUpdateNotificationStateFor \(characteristic)")
        _subscribeCompleteCallbacks[characteristic]?(UnsafeRawPointer(board), error == nil ? 0 : 1)
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        _writeIfNeeded()
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {}

}


// MARK: - Internals (Connection w/ `MetaWearScanner` as `CBCentralManagerDelegate`)

internal extension MetaWear {

    /// Kicks off device setup by discovering services when the `MetaWearScanner`, as `CBCentralManagerDelegate`, receives `didConnect`.
    ///
    func _scannerDidConnect() {
        peripheral.discoverServices([
            .metaWearService,
            .metaWearDfuService,
            .batteryService,
            .disService
        ])
        logDelegate?.logWith(.info, message: "didConnect")
    }

    /// Updates state when the `MetaWearScanner`, as `CBCentralManagerDelegate`, receives `didFailToConnect`.
    ///
    func _scannerDidFailToConnect(error: Error?) {
        _invokeConnectionHandlers(error: error, cancelled: false)
        _invokeDisconnectionHandlers(error: error)
        logDelegate?.logWith(.info, message: "didFailToConnect: \(String(describing: error))")
    }

    /// Updates state when the `MetaWearScanner`, as `CBCentralManagerDelegate`, receives `didDisconnectPeripheral` or `centralManagerDidUpdateState` where the state is not `.poweredOn`.
    ///
    func _scannerDidDisconnectPeripheral(error: Error?) {
        _invokeConnectionHandlers(error: error, cancelled: error == nil)
        _invokeDisconnectionHandlers(error: error)
        _connectInterrupts = 0
        logDelegate?.logWith(.info, message: "didDisconnectPeripheral: \(String(describing: error))")
    }

    /// Updates state when the `MetaWearScanner` discovered a MetaWear in `didDiscover` method of `CBCentralManagerDelegate`.
    ///
    func _scannerDidDiscover(advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Self._adQueue.sync {
            _adReceivedSubject.send((rssi,advertisementData))

            self._adData = advertisementData

            if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                self.bleQueue.async {
                    self.isMetaBoot = services.contains(.metaWearDfuService)
                }
            }
        }
        _updateRSSIValues(RSSI: RSSI)
        logDelegate?.logWith(.info, message: "didDiscover: \(RSSI)")
    }

}


// MARK: - Internals (Device Setup and Connection)

private extension MetaWear {

    func _setupCppSDK_start() {
        mbl_mw_metawearboard_initialize(board, bridge(obj: self)) { (context, board, errorCode) in
            let device: MetaWear = bridge(ptr: context!)

            let initializedCorrectly = errorCode == 0
            guard initializedCorrectly else {
                device._setupCppSDK_didFail("Board initialization failed: \(errorCode)")
                return
            }
            device._setupCppSDK_finalize()
        }
    }

    func _setupCppSDK_finalize() {
        _setupMacToken?.cancel()
        _setupMacToken = self
            .publish()
            .read(.deviceInformation)
            .sink { [weak self] completion in
                switch completion {
                    case .finished: return
                    case .failure(let error):
                        self?._setupCppSDK_didFail(error.chainableDescription)
                }
            } receiveValue: { [weak self] info in
                guard let self = self else { return }
                self.info = info
                UserDefaults.MetaWear.rememberLocalDevice(self.peripheral.identifier, info.mac)
                self._setupCppSDK_didSucceed()
            }
    }

    func _setupCppSDK_didSucceed() {
        bleQueue.async { [weak self] in
            let didInterrupt = (self?._connectInterrupts ?? 1) > 0
            self?._invokeConnectionHandlers(error: nil, cancelled: didInterrupt)
        }
    }

    func _setupCppSDK_didFail(_ msg: String) {
        bleQueue.async { [weak self] in
            let error = MWError.operationFailed(msg)
            self?._invokeConnectionHandlers(error: error, cancelled: false)
            self?.disconnect()
        }
    }

#warning("Is reading MAC going to be an issue?")
    func _didDiscoverCharacteristicsForMetaBoot() {
        // Setup for MetaBoot
        self.publish().read(.deviceInformation)
            .sink { completion in
                guard case let .failure(error) = completion else { return }
                self._invokeConnectionHandlers(error: error, cancelled: false)
            } receiveValue: { info in
                self.info = info
            }
            .store(in: &_subsDiscovery)
    }

    /// Complete connection-related pipelines upon a cancel request or an error during device setup methods (e.g., in `CBCharacteristic` discovery). If connection is successful, move the pipelines into the disconnect promise queue.
    ///
    func _invokeConnectionHandlers(error: Error?, cancelled: Bool) {
        assert(DispatchQueue.isOnBleQueue())
        if cancelled == false && error == nil {
            self._connectionStateSubject.send(.connected)
        }
        // Clear out the connectionSources array now because we use the
        // length as an indication of a pending operation, and if any of
        // the callback call connectAndSetup, we need the right thing to happen
        let localConnectionSubjects = _connectSubjects
        _connectSubjects.removeAll(keepingCapacity: true)

        if let error = error {
            localConnectionSubjects.forEach {
                $0.send(completion: .failure( .operationFailed(error.localizedDescription) ))
            }

        } else if cancelled {
            localConnectionSubjects.forEach { $0.send(completion: .finished) }
        } else {
            localConnectionSubjects.forEach { $0.send(self) }
            _disconnectSubjects.append(contentsOf: localConnectionSubjects)
        }
    }

    /// Terminate connection-related pipelines or read promises upon a disconnect request or event or an error during setup methods.
    ///
    func _invokeDisconnectionHandlers(error: Error?) {
        assert(DispatchQueue.isOnBleQueue())

        _connectionStateSubject.send(.disconnected)

        // Inform the C++ SDK
        _onDisconnectCallback?(UnsafeRawPointer(board), 0)
        _onDisconnectCallback = nil

        let isUnexpected = (error != nil) && (error as? CBError)?.code != .peripheralDisconnected
        _disconnectSubjects.forEach {
            isUnexpected
            ? $0.send(completion: .failure( .operationFailed(error!.localizedDescription) ))
            : $0.send(completion: .finished)
        }
        _disconnectSubjects.removeAll(keepingCapacity: true)

        _gattCharMap = [:]
        _subscribeCompleteCallbacks = [:]
        _onDataCallbacks = [:]
        _onReadCallbacks = [:]

        _readCharacteristicSubjects.forEach { $0.value.forEach {
            isUnexpected
            ? $0.send(completion: .failure( .operationFailed("Disconnected before read finished") ))
            : $0.send(completion: .finished)
        }}
        _readCharacteristicSubjects.removeAll(keepingCapacity: true)

        _subsDiscovery.forEach { $0.cancel() }
        _setupMacToken?.cancel()

        _writeQueue.removeAll()
        _commandCount = 0
    }

    static func _buildConnectPublisher(_ weakSelf: MetaWear?, _ isConnected: Bool) -> AnyPublisher<MetaWear,MWError> {
        if isConnected {
            return _buildConnectPublisher_AlreadyConnected(weakSelf)

            // Exception: Connection should be interrupted
        } else if (weakSelf?._connectInterrupts ?? 0) > 0 {
            return _buildConnectPublisher_ClearInterrupts(weakSelf)

            // Connect
        } else {
            return _buildConnectPublisher_StartNew(weakSelf)
        }
    }

    static func _buildConnectPublisher_AlreadyConnected(_ weakSelf: MetaWear?) -> AnyPublisher<MetaWear,MWError> {
        let subject = PassthroughSubject<MetaWear, MWError>()
        // 1. Link returned publisher into disconnect messages
        weakSelf?._disconnectSubjects.append(subject)

        // 2. Send self-reference to clarify successful state (silence would be ambiguous)
        return subject
            .handleEvents(receiveSubscription: { [weak subject, weak weakSelf] _ in
                guard let self = weakSelf else { return }
                subject?.send(self)
            })
            .erase(subscribeOn: weakSelf?.bleQueue ?? .global())
    }

    static func _buildConnectPublisher_StartNew(_ weakSelf: MetaWear?)  -> AnyPublisher<MetaWear,MWError> {
        let subject = PassthroughSubject<MetaWear, MWError>()
        weakSelf?._connectSubjects.append(subject)
        if weakSelf?._connectSubjects.endIndex == 1 {
            weakSelf?._connectionStateSubject.send(.connecting)
            weakSelf?.scanner.connect(weakSelf)
        }

        return subject.eraseToAnyPublisher()
    }

    static func _buildConnectPublisher_ClearInterrupts(_ weakSelf: MetaWear?)  -> AnyPublisher<MetaWear,MWError> {
        let subject = PassthroughSubject<MetaWear, MWError>()
        weakSelf?._disconnectSubjects.append(subject)
        weakSelf?._invokeDisconnectionHandlers(error: nil)
        weakSelf?._connectInterrupts = 0
        defer { subject.send(completion: .finished) }
        return subject.eraseToAnyPublisher()
    }

}


// MARK: - Internals (GattChar / write / non-self closures for `MblMwBtleConnection` initialization)

private extension MetaWear {

    func _writeIfNeeded() {
        guard !_writeQueue.isEmpty else { return }
        var canSendWriteWithoutResponse = true
        // Starting from iOS 11 and MacOS 10.13 we have a robust way to check
        // if we can send a message without response and not loose it, so no longer
        // need to arbitrary send every 10th message with response
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            // The peripheral.canSendWriteWithoutResponse often returns false before
            // even we start sending, so always send the first
            if _commandCount != 0 {
                guard peripheral.canSendWriteWithoutResponse else { return }
            }
        } else {
            // Throttle by having every Nth request wait for response
            canSendWriteWithoutResponse = !(_commandCount % 10 == 0)
        }
        _commandCount += 1
        let (data, charToWrite, requestedType) = _writeQueue.removeFirst()
        let type: CBCharacteristicWriteType = canSendWriteWithoutResponse ? requestedType : .withResponse
        logDelegate?.logWith(.info, message: "Writing \(type == .withoutResponse ? "NO-RSP" : "   RSP"): \(charToWrite.uuid) \(data.hexEncodedString())")
        peripheral.writeValue(data, for: charToWrite, type: type)
        _writeIfNeeded()
    }

    func _getCBCharacteristic(_ characteristicPtr: UnsafePointer<MblMwGattChar>?) -> CBCharacteristic? {
        guard let characteristicPtr = characteristicPtr else { return nil }

        if let characteristic = _gattCharMap[characteristicPtr.pointee] {
            return characteristic
        }

        let serviceUUID = characteristicPtr.pointee.serviceUUID
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return nil }

        let characteristicUUID = characteristicPtr.pointee.characteristicUUID
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID }) else { return nil }

        _gattCharMap[characteristicPtr.pointee] = characteristic
        return characteristic
    }
}

fileprivate func _writeGattChar(context: UnsafeMutableRawPointer?,
                                caller: UnsafeRawPointer?,
                                writeType: MblMwGattCharWriteType,
                                characteristicPtr: UnsafePointer<MblMwGattChar>?,
                                valuePtr: UnsafePointer<UInt8>?,
                                length: UInt8) {
    let device: MetaWear = bridge(ptr: context!)
    if let charToWrite = device._getCBCharacteristic(characteristicPtr) {
        let data = Data(bytes: valuePtr!, count: Int(length))
        let type: CBCharacteristicWriteType = writeType == MBL_MW_GATT_CHAR_WRITE_WITH_RESPONSE ? .withResponse : .withoutResponse
        DispatchQueue.onBleQueue(device.bleQueue) {
            device._writeQueue.append((data: data, characteristic: charToWrite, type: type))
            device._writeIfNeeded()
        }
    }
}


fileprivate func _readGattChar(context: UnsafeMutableRawPointer?,
                               caller: UnsafeRawPointer?,
                               characteristicPtr: UnsafePointer<MblMwGattChar>?,
                               callback: MblMwFnIntVoidPtrArray?) {
    let device: MetaWear = bridge(ptr: context!)
    if let charToRead = device._getCBCharacteristic(characteristicPtr) {
        // Save the callback
        device._onReadCallbacks[charToRead] = callback
        // Request the read
        device.peripheral.readValue(for: charToRead)
    }
}

fileprivate func _enableNotifications(context: UnsafeMutableRawPointer?,
                                      caller: UnsafeRawPointer?,
                                      characteristicPtr: UnsafePointer<MblMwGattChar>?,
                                      onData: MblMwFnIntVoidPtrArray?,
                                      subscribeComplete: MblMwFnVoidVoidPtrInt?) {
    let device: MetaWear = bridge(ptr: context!)
    if let charToNotify = device._getCBCharacteristic(characteristicPtr) {
        // Save the callbacks
        device._onDataCallbacks[charToNotify] = onData
        device._subscribeCompleteCallbacks[charToNotify] = subscribeComplete
        // Turn on the notification stream
        device.peripheral.setNotifyValue(true, for: charToNotify)
    } else {
        subscribeComplete?(caller, 1)
    }
}

fileprivate func _onDisconnect(context: UnsafeMutableRawPointer?,
                               caller: UnsafeRawPointer?,
                               handler: MblMwFnVoidVoidPtrInt?) {
    let device: MetaWear = bridge(ptr: context!)
    device._onDisconnectCallback = handler
}


// MARK: - Internal (Signal Strength)

internal extension MetaWear {

    /// Any RSSI update from Scanner or an explicit request (by user or via the refresher timer).
    ///
    func _updateRSSIValues(RSSI: NSNumber) {
        self.bleQueue.async { [weak self] in
            self?._rssi.send(RSSI.intValue)
        }

        Self._adQueue.async { [weak self] in
            guard let self = self else { return }
            // Timestamp and save the last N RSSI samples
            let rssi = RSSI.doubleValue
            if rssi < 0 {
                self._rssiHistory.value.insert((Date(), RSSI.doubleValue), at: 0)
            }
            if self._rssiHistory.value.count > 10 {
                self._rssiHistory.value.removeLast()
            }
        }
    }

    /// Filter the last received RSSI values into a less jumpy depiction of signal strength.
    ///
    /// - Parameter lastNSeconds: Averaging period (default 5 seconds)
    /// - Returns: Averaged value. Falls to zero when disconnected and no recent values fall into the averaging window.
    ///
    static func averageRSSI(_ history: [(date: Date, rssi: Double)],
                            lastNSeconds: Double = 5.0) -> Double {
        let filteredRSSI = history.prefix {
            -$0.date.timeIntervalSinceNow < lastNSeconds
        }
        guard filteredRSSI.endIndex > 0 else { return -100 }
        let sumArray = filteredRSSI.reduce(0.0) { $0 + $1.1 }
        return sumArray / Double(filteredRSSI.count)
    }

    func _startRefreshingRSSI() {
        _rssiRefreshSources += 1
        guard _rssiRefreshSources == 1 else { return }
        _refreshables["rssi"] = _refreshTimer
            .sink { [weak self] date in
                guard self?.connectionState == .connected else { return }
                Self._adQueue.sync {
                    /// Only update if there isn't a recently refreshed value
                    guard (self?._rssiHistory.value.last?.0.distance(to: date) ?? 5) > 4 else { return }
                    self?.bleQueue.async { [weak self] in
                        self?.updateRSSI()
                    }
                }
            }
    }

    func _stopRefreshingRSSI() {
        _rssiRefreshSources -= 1
        guard _rssiRefreshSources == 0 else { return }
        _refreshables["rssi"]?.cancel()
        _refreshables.removeValue(forKey: "rssi")
    }

    func _makeRSSIPublisher() -> AnyPublisher<Int,Never> {
        _rssi
            .share()
            .handleEvents(receiveSubscription: {  [weak self] _ in
                self?._startRefreshingRSSI()
            })
            .handleEvents(receiveCancel: { [weak self] in
                self?._stopRefreshingRSSI()
            })
            .erase(subscribeOn: bleQueue)
    }

    func _makeRSSIAveragePublisher() -> AnyPublisher<Int,Never> {
        self._rssiHistory
            .map { Int(Self.averageRSSI($0, lastNSeconds: 5)) }
            .subscribe(on: Self._adQueue)
            .share()
            .handleEvents(receiveSubscription: {  [weak self] _ in
                self?._startRefreshingRSSI()
            })
            .handleEvents(receiveCancel: { [weak self] in
                self?._stopRefreshingRSSI()
            })
            .erase(subscribeOn: bleQueue)
    }

    static func _makeFiveSecondRefresher(_ queue: DispatchQueue) -> AnyPublisher<Date,Never> {
        Timer.TimerPublisher
            .init(interval: 5, tolerance: 1, runLoop: RunLoop.main, mode: .default, options: nil)
            .autoconnect()
            .share()
            .receive(on: queue)
            .erase(subscribeOn: queue)
    }
}
