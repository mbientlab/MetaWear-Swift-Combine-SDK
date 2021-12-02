// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import MetaWearCpp
import Combine


/// Each MetaWear object corresponds a physical MetaWear board. Many
/// type-safe methods here abstract working with C++ functions for
/// connecting, disconnecting, saving and restoring state, and
/// performing commands like logging and streaming.
///
/// Most methods in this SDK are async `Combine` operators on
/// the `MetaWear.publish*()` publishers. You can find these operators
/// by code completion or in`Publisher<MetaWear,*>`. Unfortunately,
/// Xcode 13.0's documentation browser does not show extensions to
/// out-of-module types like `Publisher`.
///
///
/// Example 1. Stream safely-typed data once connected the first time
/// ```swift
/// let stream = metawear
///       .publishWhenConnected()
///       .first()
///       .stream(.ambientLight())
///       .sink { [weak self] value in
///           self?.lux = value
///       }
///
/// stream.cancel()
///
/// // Note: `.publishWhenConnected()` only waits for, not starts a connection.
/// // To start, call `.connect()` or `.connectPublisher()`.
/// ```
///
/// Example 2. Read battery percentage remaining if connected when the call is placed.
/// ```swift
/// metawear
///       .publishIfConnected()
///       .read(.batteryLife)
///       .sink(receiveCompletion: {
///           switch $0 {
///               case .error(let error):   // Setup error
///               case .finished:           // Disconnected by request
///           }
///       }, receiveValue: { [weak self] value in {
///           self?.battery = value         // Connected & read
///       })
///
/// ```
///
/// Example 3. Mix C++ methods with Combine
/// ```swift
///
/// ```
/// - Warning: Use the `apiAccessQueue` to read `MetaWear` properties and place calls
/// into the MetaWear C++ library.
///
/// - Tip: All publishers with the alias `MWPublisher` perform work on
/// the `apiAccessQueue` for you.
///
public class MetaWear: NSObject {

    // MARK: - References

    /// To prevent crashes, use this queue for all MetaWearCpp library calls.
    public var apiAccessQueue: DispatchQueue { scanner?.bleQueue ?? DispatchQueue.global() }

    /// This device's CoreBluetooth object
    public let peripheral: CBPeripheral

    /// Scanner that discovered this device
    public private(set) weak var scanner: MetaWearScanner?

    /// Receives device activity
    public var logDelegate: MWConsoleLoggerDelegate?

    /// Pass to MetaWearCpp functions
    public private(set) var board: MWBoard!


    // MARK: - Connection State

    /// Has BLE connection and an initialized MetaWearCpp library
    public private(set) var isConnectedAndSetup = false

    /// Whether advertised or discovered as a MetaBoot
    public private(set) var isMetaBoot = false

    /// Stream of connecting, connected (and with C++ library setup), disconnecting, and disconnected events.
    public let connectionState: AnyPublisher<CBPeripheralState, Never>


    // MARK: - Signal (refreshed by `MetaWearScanner` activity)

    /// Last signal strength indicator received. Updates while `MetaWearScanner` or an rssi Publisher is active, plus when you call `updateRSSI()`.
    public var rssi: Int { _rssi.value }

    /// Most recent RSSI, as pushed from an active `MetaWearScanner` or from `CBPeripheralDelegate` about every 5 seconds by automatic calls to `updateRSSI()`. -100  can indicate disconnection.
    public private(set) lazy var rssiPublisher: AnyPublisher<Int, Never> = _makeRSSIPublisher()

    /// Average of the last 5 seconds of signal strength, as pushed from an active `MetaWearScanner` or from `CBPeripheralDelegate` about every 5 seconds by automatic calls to `updateRSSI()`. -100 can indicate disconnection.
    public private(set) lazy var rssiMovingAveragePublisher: AnyPublisher<Int,Never> = _makeRSSIAveragePublisher()

    /// Most recent signal strength and advertisement packet data, while the `MetaWearScanner` is active.
    public let advertisementReceived: AnyPublisher<(rssi: Int, advertisementData: [String:Any]), Never>

    /// Last advertisement packet data received.
    public var advertisementData: [String : Any] {
        get { Self._adQueue.sync { _adData } }
    }


    // MARK: - Device Identity

    /// The MAC address (available after first connection) is a 6-byte unique identifier for a MetaWear and any Bluetooth device (e.g., F1:4A:45:90:AC:9D).
    ///
    /// To maximize privacy, Apple obfuscates MAC addresses by replacing them with an auto-generated `CBUUID`. While stable locally, it differs between a user's phones and computers. As such, we make the MAC available via our own MetaSensor SDKs and via the Bluetooth Ad packet for easy and fast retrieval in iOS.
    ///
    public internal(set) var mac: String?

    /// Model, serial, firmware, hardware, and manufacturer details (available after first connection)
    public internal(set) var info: MetaWear.DeviceInformation?

    /// Latest advertised name. Note: The CBPeripheral.name property might be cached.
    public var name: String {
        return Self._adQueue.sync {
            let adName = _adData[CBAdvertisementDataLocalNameKey] as? String
            return adName ?? peripheral.name ?? "MetaWear"
        }
    }

    /// Lazily builds a table of the board's modules (sync)
    public lazy private(set) var modules: Set<MWModules> = MWModules.detect(in: board)

    // MARK: - Internal Properties
    /// When executing a test suite serially using a shared scanner against the same device, beware that MetaWear device instances are shared between your tests. You may need to set this to zero for certain tests where you are evaluating connection and disconnection behavior from a disconnected starting state. This is incremented by disconnect calls to interrupt an ongoing or the next scheduled connect request.
    public var _connectInterrupts: Int = 0

    // Delegate responses to async pipelines in setup/operation
    fileprivate var _setupMacToken: AnyCancellable? = nil
    fileprivate var _connectionStateSubject = CurrentValueSubject<CBPeripheralState,Never>(.disconnected)
    fileprivate var _connectSubjects: [PassthroughSubject<MetaWear, MWError>] = []
    fileprivate var _disconnectSubjects: [PassthroughSubject<MetaWear, MWError>] = []
    fileprivate var _readCharacteristicSubjects: [CBCharacteristic: [PassthroughSubject<Data, MWError>]] = [:]
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

    /// Please use `MetaWearScanner` to initialize MetaWears properly. To subclass the scanner, you may need to use this initializer.
    ///
    /// - Parameters:
    ///   - peripheral: Discovered `CBPeripheral`
    ///   - scanner: Scanner that discovered the peripheral
    ///
    public init(peripheral: CBPeripheral, scanner: MetaWearScanner) {
        self.peripheral = peripheral
        self.scanner = scanner
        self._refreshTimer = Self._makeFiveSecondRefresher()

        self.connectionState = _connectionStateSubject.erase(subscribeOn: scanner.bleQueue)

        self.advertisementReceived = self._adReceivedSubject
            .subscribe(on: Self._adQueue)
            .receive(on: scanner.bleQueue)
            .share()
            .eraseToAnyPublisher()

        super.init()
        self.peripheral.delegate = self
        var connection = MblMwBtleConnection(context: bridge(obj: self),
                                             write_gatt_char: _writeGattChar,
                                             read_gatt_char: _readGattChar,
                                             enable_notifications: _enableNotifications,
                                             on_disconnect: _onDisconnect)
        self.board = mbl_mw_metawearboard_create(&connection)
        mbl_mw_metawearboard_set_time_for_response(self.board, 0)
        self.mac = UserDefaults.MetaWearCore.getMac(for: self)
    }
}

// MARK: - Public API (Connection Process)

public extension MetaWear {

    /// Connect to this MetaWear and initialize the C++ library.
    ///
    /// Enqueues a connection request to the parent MetaWearScanner.
    /// For connection state changes, subscribe to `connectionState` or
    /// use the `connect() -> MWPublisher` variant.
    ///
    func connect() {
        apiAccessQueue.async { [weak self] in
            guard let self = self, self.isConnectedAndSetup == false else { return }
            guard self._connectInterrupts == 0 else {
                self._connectInterrupts = 0
                return
            }
            self.scanner?.connect(self)
            self._connectionStateSubject.send(.connecting)
        }
    }

    /// Connect to this MetaWear and initialize the C++ library.
    ///
    /// This publisher enqueues a connection request to the
    /// scanner that discovered it. It behaves as follows:
    /// - on connection (or if already), sends a reference to self
    /// - on disconnect, completes without error
    /// - on a setup fault, completes with error
    /// - if you cancel the `AnyCancellable`, attempts device disconnect
    /// - subscribes and sends on the `apiAccessQueue`
    ///
    /// Internally, this is an erased `PassthroughSubject`
    /// that is cached for `CBPeripheralDelegate` methods
    /// to call as setup progresses.
    ///
    /// - Returns: On the `apiAccessQueue` an error, device reference (success), or completion on error-less disconnect
    ///
    func connectPublisher() -> MWPublisher<MetaWear> {
        MetaWear._buildConnectPublisher(self, isConnectedAndSetup)
            .handleEvents(receiveCancel: { [weak self] in
                self?.disconnect()
            })
            .share()
            .erase(subscribeOn: apiAccessQueue)
    }

    /// Cancels a current connection, an ongoing connection attempt, or the next connection attempt. In the latter case, this method is idempotent (i.e., only the next connection attempt is cancelled).
    ///
    func disconnect() {
        apiAccessQueue.async { [self] in
            let state = _connectionStateSubject.value
            self._connectionStateSubject.send(state == .disconnected ? .disconnected : .disconnecting)

            /// A connect request might come in ahead of a response by the scanner
            if self._connectSubjects.isEmpty && self._disconnectSubjects.isEmpty && state != .connected {
                _connectInterrupts += 1

            } else {
                scanner?.cancelConnection(self)
                _connectInterrupts = 0
            }
        }
    }
}

// MARK: - Public API (Reconnection to Known Devices)

public extension MetaWear {

    /// Before reconnecting to a device, restores data for Cpp library by deserializing data you previously saved to the `uniqueURL`. You are responsible for writing data.
    ///
    func stateLoadFromUniqueURL() {
        if let data = try? Data(contentsOf: uniqueURL()) {
            stateDeserialize([UInt8](data))
        }
    }

    /// Dump all MetaWearCpp library state (prior to disconnection).
    ///
    func stateSerialize() -> [UInt8] {
        var count: UInt32 = 0
        let start = mbl_mw_metawearboard_serialize(board, &count)
        let data = Array(UnsafeBufferPointer(start: start, count: Int(count)))
        mbl_mw_memory_free(start)
        return data
    }

    /// Restore MetaWearCpp library state, must be called before `connectAndSetup()`.
    ///
    func stateDeserialize(_ _data: [UInt8]) {
        var data = _data
        mbl_mw_metawearboard_deserialize(board, &data, UInt32(data.count))
    }

    /// Create a file name unique to this device, based on its `CBPeripheral` identifier UUID. The returned URL is inside the user's Application Support directory, within a subfolder: `com.mbientlab.devices`.
    ///
    func uniqueURL() -> URL {
        var url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.mbientlab.devices", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        url.appendPathComponent(peripheral.identifier.uuidString + ".file")
        return url
    }

    /// Stops logging, deletes recorded logs and macros, tears down the board and disconnects.
    ///
    func resetToFactoryDefaults() {
        mbl_mw_logging_stop(board)
        mbl_mw_metawearboard_tear_down(board)
        mbl_mw_logging_clear_entries(board)
        mbl_mw_macro_erase_all(board)
        mbl_mw_debug_reset_after_gc(board) //05
        mbl_mw_debug_disconnect(board) //06
    }
}

// MARK; - Public API (Publishers to Kickoff Reads/Writes/Logs/Streams of Board Signals)

public extension MetaWear {

    /// Publishes this MetaWear once, regardless of connection state.
    ///
    func publish() -> MWPublisher<MetaWear> {
        Just(self)
            .setFailureType(to: MWError.self)
            .erase(subscribeOn: self.apiAccessQueue)
    }

    /// Publishes if connected and setup at start, failing if not
    ///
    func publishIfConnected() -> MWPublisher<MetaWear> {
        isConnectedAndSetup
        ? Just(self)
            .setFailureType(to: MWError.self)
            .erase(subscribeOn: self.apiAccessQueue)
        : Fail(
            outputType: MetaWear.self,
            failure: MWError.operationFailed(
                "Connected MetaWear required. Currently: \(peripheral.state.debugDescription)"
            ))
            .erase(subscribeOn: self.apiAccessQueue)
    }

    /// Publishes after connection and setup
    ///
    func publishWhenConnected() -> AnyPublisher<MetaWear,Never> {
        _connectionStateSubject
            .compactMap { $0 == .connected ? self : nil }
            .eraseToAnyPublisher()
    }

    /// Publishes after disconnection
    ///
    func publishWhenDisconnected() -> AnyPublisher<MetaWear,Never> {
        _connectionStateSubject
            .compactMap { $0 == .disconnected ? self : nil }
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


// MARK: - Public API (Device Information)

public extension MetaWear {

    /// Requests refreshed information about this MetaWear, such as its battery percentage, serial number, model, manufacturer, and hardware and firmware versions.
    ///
    /// - Parameters:
    ///   - characteristic: Type-safe preset for `MetaWear` device information.
    ///
    /// - Returns: A completing publisher for cast data supplied by the `CoreBluetooth` framework. Requests are queued for fulfillment by the `CBPeripheralDelegate` `peripheral(:didUpdateValueFor:error:)` method.
    ///
    func readCharacteristic<T>(_ characteristic: MetaWear.ServiceCharacteristic<T>) -> MWPublisher<T> {
        if T.self == MetaWear.DeviceInformation.self {
            return MetaWear.DeviceInformation.publisher(for: self)
                .map { $0 as! T }.eraseToAnyPublisher() // Compiler workaround
                .eraseToAnyPublisher()

        } else {
            return _readData(service: characteristic.service.cbuuid, characteristic: characteristic.characteristic.cbuuid)
                .map { characteristic.parse($0) }
                .eraseToAnyPublisher()
        }
    }

    /// Request a refreshed value for the target service and characteristic.
    ///
    /// - Parameters:
    ///   - serviceUUID: See `CBUUID` static presets for MetaWear service options.
    ///   - characteristicUUID: See `CBUUID` static presets for MetaWear characteristic options.
    ///
    /// - Returns: A completing publisher for data supplied by the `CoreBluetooth` framework. Requests are queued for fulfillment by the `CBPeripheralDelegate` `peripheral(:didUpdateValueFor:error:)` method.
    ///
    func _readData(service: CBUUID, characteristic: CBUUID) -> MWPublisher<Data> {
        _getCharacteristic(service, characteristic)
            .publisher
            .flatMap { [weak self] characteristic -> AnyPublisher<Data,MWError> in
                let subject = PassthroughSubject<Data, MWError>()
                self?._readCharacteristicSubjects[characteristic, default: []].append(subject)
                self?.peripheral.readValue(for: characteristic)
                return subject.eraseToAnyPublisher()
            }
            .erase(subscribeOn: apiAccessQueue)
    }

    /// **Returns synchronously on the calling queue. Call only from `apiAccessQueue`.** Retrieves a characteristic contained in the most recently refreshed list of `CBService`.
    ///
    /// - Parameters:
    ///   - serviceUUID: See `CBUUID` static presets for MetaWear service options.
    ///   - characteristicUUID: See `CBUUID` static presets for MetaWear characteristic options.
    /// - Returns: On the calling queue. The characteristic or failure for `CBUUID` input that are invalid or not found.
    ///
    func _getCharacteristic(_ serviceUUID: CBUUID,_ characteristicUUID: CBUUID) -> Result<CBCharacteristic, MWError> {
        guard let service = self.peripheral.services?.first(where: { $0.uuid == serviceUUID })
        else { return .failure(.operationFailed("Service not found")) }

        guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID })
        else { return .failure(.operationFailed("Characteristics not found")) }

        return .success(characteristic)
    }
}


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
                self.apiAccessQueue.async {
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

    func _didDiscoverCharacteristicsForMetaBoot() {
        readCharacteristic(.allDeviceInformation)
            .sink { completion in
                guard case let .failure(error) = completion else { return }
                self._invokeConnectionHandlers(error: error, cancelled: false)
            } receiveValue: { info in
                self.info = info
            }
            .store(in: &_subsDiscovery)
    }

    func _setupCppSDK_start() {
        mbl_mw_metawearboard_initialize(board, bridge(obj: self)) { (context, board, errorCode) in
            let device: MetaWear = bridge(ptr: context!)

            let initializedCorrectly = errorCode == 0
            guard initializedCorrectly else {
                device._setupCppSDK_didFail("Board initialization failed: \(errorCode)")
                return
            }

            // Grab `DeviceInformation`
            let rawInfo = mbl_mw_metawearboard_get_device_information(device.board)
            device.info = rawInfo?.pointee.convert()
            mbl_mw_memory_free(UnsafeMutableRawPointer(mutating: rawInfo))

            device._setupCppSDK_finalize()
        }
    }

    func _setupCppSDK_finalize() {
        guard mac == nil else {
            _setupCppSDK_didSucceed()
            return
        }

        _setupMacToken?.cancel()
        _setupMacToken = self
            .publish()
            .read(.macAddress)
            .map(\.value)
            .sink { [weak self] completion in
                switch completion {
                    case .finished: return
                    case .failure(let error):
                        self?._setupCppSDK_didFail(error.chainableDescription)
                }
            } receiveValue: { [weak self] macString in
                guard let self = self else { return }
                self.mac = macString
                UserDefaults.MetaWearCore.setMac(macString, for: self)
                self._setupCppSDK_didSucceed()
            }
    }

    func _setupCppSDK_didSucceed() {
        apiAccessQueue.async { [weak self] in
            let didInterrupt = (self?._connectInterrupts ?? 1) > 0
            self?._invokeConnectionHandlers(error: nil, cancelled: didInterrupt)
        }
    }

    func _setupCppSDK_didFail(_ msg: String) {
        apiAccessQueue.async { [weak self] in
            let error = MWError.operationFailed(msg)
            self?._invokeConnectionHandlers(error: error, cancelled: false)
            self?.disconnect()
        }
    }

    /// Complete connection-related pipelines upon a cancel request or an error during device setup methods (e.g., in `CBCharacteristic` discovery). If connection is successful, move the pipelines into the disconnect promise queue.
    ///
    func _invokeConnectionHandlers(error: Error?, cancelled: Bool) {
        assert(DispatchQueue.isBleQueue)
        if cancelled == false && error == nil {
            self.isConnectedAndSetup = true
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
        assert(DispatchQueue.isBleQueue)

        isConnectedAndSetup = false
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
            .erase(subscribeOn: weakSelf?.apiAccessQueue ?? .global())
    }

    static func _buildConnectPublisher_StartNew(_ weakSelf: MetaWear?)  -> AnyPublisher<MetaWear,MWError> {
        let subject = PassthroughSubject<MetaWear, MWError>()
        weakSelf?._connectSubjects.append(subject)
        if weakSelf?._connectSubjects.endIndex == 1 {
            weakSelf?._connectionStateSubject.send(.connecting)
            weakSelf?.scanner?.connect(weakSelf)
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
        if DispatchQueue.isBleQueue {
            device._writeQueue.append((data: data, characteristic: charToWrite, type: type))
            device._writeIfNeeded()
        } else {
            device.apiAccessQueue.async {
                device._writeQueue.append((data: data, characteristic: charToWrite, type: type))
                device._writeIfNeeded()
            }
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

private extension MetaWear {

    /// Any RSSI update from Scanner or an explicit request (by user or via the refresher timer).
    ///
    func _updateRSSIValues(RSSI: NSNumber) {
        self.apiAccessQueue.async { [weak self] in
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
        Self._adQueue.sync {
            let filteredRSSI = history.prefix {
                -$0.date.timeIntervalSinceNow < lastNSeconds
            }
            guard filteredRSSI.count > 0 else { return -100 }
            let sumArray = filteredRSSI.reduce(0.0) { $0 + $1.1 }
            return sumArray / Double(filteredRSSI.count)
        }
    }

    func _startRefreshingRSSI() {
        _rssiRefreshSources += 1
        guard _rssiRefreshSources == 1 else { return }
        _refreshables["rssi"] = _refreshTimer
            .sink { [weak self] date in
                Self._adQueue.sync {
                    /// Only update if there isn't a recently refreshed value
                    guard (self?._rssiHistory.value.last?.0.distance(to: date) ?? 5) > 4 else { return }
                    self?.apiAccessQueue.async { [weak self] in
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
            .erase(subscribeOn: apiAccessQueue)
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
            .erase(subscribeOn: apiAccessQueue)
    }

    static func _makeFiveSecondRefresher() -> AnyPublisher<Date,Never> {
        Timer.TimerPublisher
            .init(interval: 5, tolerance: 1, runLoop: .current, mode: .default, options: nil)
            .autoconnect()
            .share()
            .eraseToAnyPublisher()
    }
}
