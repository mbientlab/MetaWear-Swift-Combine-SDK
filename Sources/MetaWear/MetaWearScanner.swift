// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import Combine

public extension MetaWearScanner {
    static let shared = MetaWearScanner()
    static let sharedRestore = MetaWearScanner(restoreIdentifier: "MetaWearScanner.shared")
}

public typealias CBPeripheralIdentifier = UUID

/// Start scanning for MetaWear devices without having to understand all of CoreBluetooth. Pipelines return on the scanner's unique `bleQueue`.
///
public class MetaWearScanner: NSObject {

    // MARK: - Discovered Devices

    /// All MetaWears discovered by the `CBCentralManager`,
    ///  including those nearby but never connected to or those
    ///  not nearby but remembered by CoreBluetooth from a prior
    ///  session. Read only on the `bleQueue`.
    public private(set) var deviceMap: [CBPeripheralIdentifier: MetaWear] = [:]

    /// Publishes the `deviceMap` after adding a new member.
    public private(set) lazy var discoveredDevices: AnyPublisher<[CBPeripheralIdentifier: MetaWear], Never> = _makeDiscoveredDevicesPublisher()

    /// Publishes only newly discovered `MetaWear`
    /// (from `centralManager(:didDiscover:advertisementData:rssi:)`)
    public private(set) lazy var didDiscoverUniqued: AnyPublisher<MetaWear, Never> = _makeDidDiscoverUniquedPublisher()

    /// Publishes any `MetaWear` discovery
    /// (from `centralManager(:didDiscover:advertisementData:rssi:)`)
    public private(set) lazy var didDiscover: AnyPublisher<MetaWear, Never> = _makeDidDiscoverPublisher()

    // MARK: - Scanning State

    /// Stream of `CBCentralManager.state` updates, 
    /// such as for authorization or power status.
    /// (from `centralManagerDidUpdateState`)
    public private(set) lazy var centralManagerDidUpdateState: AnyPublisher<CBManagerState, Never> = _makeCentralDidUpdatePublisher()

    /// Filtered and failing stream of `CBCentralManager.state`
    /// updates. Skips unknown and resetting states changes,
    /// but publishes powerOn and fails on power off, unsupported,
    /// and unauthorized.
    public private(set) lazy var centralManagerFilteredDidUpdateState: AnyPublisher<CBManagerState, MWError> = _makeFilteredCentralDidUpdatePublisher()

    /// Whether or not the scanner's CBCentralManager is scanning.
    public var isScanning: Bool { self.central.isScanning }

    /// Updates for the scanner's CBCentralManager activity state.
    public lazy private(set) var isScanningPublisher = self.central.publisher(for: \.isScanning).eraseToAnyPublisher()


    // MARK: - Bluetooth API Queue and CBCentralManager

    /// Queue used by the `CBCentralManager` for all
    /// BLE operations and reads. All pipelines return
    /// on this queue.
    public let bleQueue: DispatchQueue
    public private(set) var central: CBCentralManager! = nil

    /// Provide a restore identifier if desired. Call
    /// `retrieveSavedMetaWears` and then `startScan`
    /// to gather remembered MetaWears and newly discovered
    /// nearby MetaWears (once Bluetooth is powered on).
    ///
    public init(restoreIdentifier: String? = nil) {
        self.bleQueue = .makeScannerQueue()
        super.init()
        _makeCentralManager(with: restoreIdentifier)
    }

    // Internal
    private var runOnPowerOn: [() -> Void] = []
    private var runOnPowerOff: [() -> Void] = []
    private lazy var didUpdateStateSubject = CurrentValueSubject<CBManagerState,Never>(central.state)
    private lazy var didDiscoverMetaWearsSubject = PassthroughSubject<MetaWear,Never>()
    private lazy var didDiscoverMetaWearsUniquedSubject = PassthroughSubject<MetaWear,Never>()
}

// MARK: - Public API — Scan / Retrieve Connected MetaWears

public extension MetaWearScanner {

    /// Start the scanning process for MetaWear or MetaBoot
    /// devices. Discovered devices are delivered by the
    /// `didDiscover` publisher.
    /// - Parameter higherPerformanceMode: An Apple API that
    /// increases performance at expense of battery life
    /// (called `allowDuplicates`)
    ///
    func startScan(higherPerformanceMode: Bool) {
        runWhenPoweredOn {
            self.central.scanForPeripherals(
                withServices: [.metaWearService, .metaWearDfuService],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: higherPerformanceMode]
            )

            // Restart scanning if BLE state toggles off then on
            self.runOnPowerOff.append { [unowned self] in
                self.startScan(higherPerformanceMode: higherPerformanceMode)
            }
        }
    }

    /// Stop scanning for novel devices
    ///
    func stopScan() {
        runWhenPoweredOn {
            self.central.stopScan()
        }
    }

    /// Unsorted list of devices stored via `MetaWear.remember()` or the identifiers you provide.
    /// - Returns: Publisher that completes only when
    /// `CBCentralManager` is `.poweredOn`.
    ///
    func retrieveSavedMetaWears(withIdentifiers: [CBPeripheralIdentifier] = UserDefaults._rememberedUUIDs) -> AnyPublisher<[MetaWear],Never> {
        runWhenPoweredOn { [weak self] promise in
            guard let self = self else { return }
            let devices = self.central
                .retrievePeripherals(withIdentifiers: withIdentifiers)
                .map { peripheral -> MetaWear in
                    let device = self.deviceMap[peripheral.identifier] ?? MetaWear(peripheral: peripheral, scanner: self)
                    self.deviceMap[peripheral.identifier] = device
                    return device
                }

            promise(.success(devices))
        }
    }

    /// Populates the scanner's device map with MetaWears
    /// stored via `MetaWear.remember()` or the identifiers
    /// you provide. Runs after `CBCentralManager` is `.poweredOn`.
    ///
    func retrieveSavedMetaWearsAsync(withIdentifiers: [CBPeripheralIdentifier] = UserDefaults._rememberedUUIDs) {
        runWhenPoweredOn { [weak self] in
            guard let self = self else { return }
            self.central
                .retrievePeripherals(withIdentifiers: withIdentifiers)
                .forEach { peripheral in
                    let device = self.deviceMap[peripheral.identifier] ?? MetaWear(peripheral: peripheral, scanner: self)
                    self.deviceMap[peripheral.identifier] = device
                }
        }
    }

    /// Unsorted list of devices that are already connected,
    /// which is useful to check after state was restored.
    /// - Returns: Publisher that completes only when
    ///  `CBCentralManager` is `.poweredOn`.
    ///
    func retrieveConnectedMetaWears() -> AnyPublisher<[MetaWear],Never> {
        runWhenPoweredOn { [weak self] promise in
            guard let self = self else { return }

            let services = [CBUUID.metaWearService, .metaWearDfuService]
            let devices = self.central.retrieveConnectedPeripherals(withServices: services)
                .map { peripheral -> MetaWear in
                    let device = self.deviceMap[peripheral.identifier] ?? MetaWear(peripheral: peripheral, scanner: self)
                    self.deviceMap[peripheral.identifier] = device
                    return device
                }

            promise(.success(devices))
        }
    }


    /// Returns a MetaWear (on your calling queue) from the ``deviceMap``.
    /// Produces a fatalError if that device does not exist.
    ///
    /// - Parameter id: `CBPeripheral.identifier`
    /// - Returns: MetaWear device
    ///
    func getMetaWear(id: UUID) -> MetaWear? {
        var metawear: MetaWear? = nil
        bleQueue.sync {
            guard let device = deviceMap[id] else { return }
            metawear = device
        }
        return metawear
    }
}


// MARK: - Internal — CBCentralManagerDelegate

extension MetaWearScanner: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // TODO: - This seems like an iOS bug.  If bluetooth powers off the
        // peripherals disconnect, but we don't get a deviceDidDisconnect callback.
        if central.state != .poweredOn {
            deviceMap.forEach { $0.value._scannerDidDisconnectPeripheral(error: MWError.bluetoothPoweredOff) }
        }

        // Execute all commands when the central is ready
        if central.state == .poweredOn {
            let localRunOnPowerOn = runOnPowerOn
            runOnPowerOn.removeAll()
            localRunOnPowerOn.forEach { $0() }

        } else if central.state == .poweredOff {
            let localRunOnPowerOff = runOnPowerOff
            runOnPowerOff.removeAll()
            localRunOnPowerOff.forEach { $0() }
        }

        didUpdateStateSubject.send(central.state)
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {

        if let device = deviceMap[peripheral.identifier] {
            device._scannerDidDiscover(advertisementData: advertisementData, rssi: RSSI)
            didDiscoverMetaWearsSubject.send(device)

        } else {
            let device = MetaWear(peripheral: peripheral, scanner: self)
            deviceMap[peripheral.identifier] = device
            device._scannerDidDiscover(advertisementData: advertisementData, rssi: RSSI)

            didDiscoverMetaWearsSubject.send(device)
            didDiscoverMetaWearsUniquedSubject.send(device)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        deviceMap[peripheral.identifier]?._scannerDidConnect()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        deviceMap[peripheral.identifier]?._scannerDidFailToConnect(error: error)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        deviceMap[peripheral.identifier]?._scannerDidDisconnectPeripheral(error: error)
    }

    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        // As an SDK, we aren't sure what operations the user is actually doing.
        // You should place code in didFinishLaunchingWithOptions to kick off any tasks
        // you expect to take place

        // An array (an instance of NSArray) of CBPeripheral objects that contains
        // all of the peripherals that were connected to the central manager
        // (or had a connection pending) at the time the app was terminated by the system.
        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else { return }
        for peripheral in peripherals {
            self.deviceMap[peripheral.identifier] = MetaWear(peripheral: peripheral, scanner: self)
        }
    }
}

// MARK: - Internal — Connection

extension MetaWearScanner {

    internal func connect(_ device: MetaWear?) {
        runWhenPoweredOn { [weak device] in
            guard let device = device else { return }
            self.central.connect(device.peripheral)
        }
    }

    internal func cancelConnection(_ device: MetaWear) {
        runWhenPoweredOn {
            self.central.cancelPeripheralConnection(device.peripheral)
        }
    }

    /// Add this device to a persistent list loaded by `.retrieveSavedMetaWears()`
    ///
    public func remember(_ device: MetaWear) {
        let idString = device.peripheral.identifier.uuidString
        var devices = UserDefaults._rememberedUUIDStrings
        if !devices.contains(idString) {
            devices.append(idString)
        }
        UserDefaults._save(uuidStrings: devices)
    }

    /// Remove this device from the persistent list loaded by `.retrieveSavedMetaWears()`
    ///
    public func forget(_ device: MetaWear) {
        var devices = UserDefaults._rememberedUUIDStrings
        if let idx = devices.firstIndex(of: device.peripheral.identifier.uuidString) {
            devices.remove(at: idx)
            UserDefaults._save(uuidStrings: devices)
        }
    }
}

// MARK: - Internal – Setup

private extension MetaWearScanner {

    func _makeCentralManager(with restoreIdentifier: String?) {
        let options: [String : Any] = restoreIdentifier == nil
        ? [:]
        : [CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifier!]
        self.central = CBCentralManager(delegate: self, queue: bleQueue, options: options)
    }

    func runWhenPoweredOn(_ code: @escaping () -> Void) {
        bleQueue.async {
            if self.central.state == .poweredOn { code() }
            else { self.runOnPowerOn.append(code) }
        }
    }

    /// Executes a closure on the BLE queue **after** subscription and **after** the scanner is powered on.
    func runWhenPoweredOn<O>(promise: @escaping ((Result<O,Never>) -> Void) -> Void) -> AnyPublisher<O,Never> {
        Deferred { [weak self] in Future<O,Never> { [weak self] future in
            self?.bleQueue.async {
                if self?.central.state == .poweredOn { promise(future) }
                else { self?.runOnPowerOn.append( { promise(future) } ) }
            }
        }}.eraseToAnyPublisher()
    }

    func _makeDidDiscoverPublisher() -> AnyPublisher<MetaWear, Never> {
        didDiscoverMetaWearsSubject
            .share()
            .erase(subscribeOn: self.bleQueue)
    }

    func _makeDidDiscoverUniquedPublisher() -> AnyPublisher<MetaWear, Never> {
        didDiscoverMetaWearsUniquedSubject
            .share()
            .erase(subscribeOn: self.bleQueue)
    }

    func _makeDiscoveredDevicesPublisher() -> AnyPublisher<[UUID: MetaWear], Never> {
        didDiscoverMetaWearsUniquedSubject
            .compactMap { [weak self] _ in self?.deviceMap }
            .share()
            .erase(subscribeOn: self.bleQueue)
    }

    func _makeCentralDidUpdatePublisher() -> AnyPublisher<CBManagerState,Never> {
        didUpdateStateSubject
            .share()
            .erase(subscribeOn: bleQueue)
    }

    func _makeFilteredCentralDidUpdatePublisher() -> AnyPublisher<CBManagerState, MWError> {
        didUpdateStateSubject
            .tryCompactMap({ state in
                switch state {
                    case .unknown: fallthrough
                    case .resetting: return nil // Updates are imminent, so provide a skippable nil
                    case .unsupported: throw MWError.bluetoothUnsupported
                    case .unauthorized: throw MWError.bluetoothUnauthorized
                    case .poweredOff: throw MWError.bluetoothPoweredOff
                    case .poweredOn: return .poweredOn
                    @unknown default: fatalError("MetaWear: New central.state values, please update.")
                }
            })
            .mapError { $0 as! MWError }
            .eraseToAnyPublisher()
    }
}

internal extension DispatchQueue {

    fileprivate static let bleQueueKey = DispatchSpecificKey<Int>()
    fileprivate static let bleQueueValue = 1111
    fileprivate static var scannerCount = 0

    class var isBleQueue: Bool {
        DispatchQueue.getSpecific(key: bleQueueKey) == bleQueueValue
    }

    static func makeScannerQueue() -> DispatchQueue {
        let queue = DispatchQueue(label: "com.mbientlab.bleQueue\(scannerCount)")
        scannerCount += 1
        queue.setSpecific(key: bleQueueKey, value: bleQueueValue)
        return queue
    }
}

// MARK: - Optional Persistence

extension UserDefaults {

    static private let _rememberedDevicesKey = "com.mbientlab.rememberedDevices"

    fileprivate static var _rememberedUUIDStrings: [String] {
        UserDefaults.standard.stringArray(forKey: UserDefaults._rememberedDevicesKey) ?? []
    }

    public static var _rememberedUUIDs: [UUID] {
        _rememberedUUIDStrings.compactMap(UUID.init(uuidString:))
    }

    static func _save(uuidStrings: [String]) {
        UserDefaults.standard.set(uuidStrings, forKey: UserDefaults._rememberedDevicesKey)
    }
}
