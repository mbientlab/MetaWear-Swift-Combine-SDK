/**
 * MetaWearScanner.swift
 * MetaWear-Swift
 *
 * Created by Stephen Schiffli on 12/14/17.
 * Copyright 2017 MbientLab Inc. All rights reserved.
 *
 * IMPORTANT: Your use of this Software is limited to those specific rights
 * granted under the terms of a software license agreement between the user who
 * downloaded the software, his/her employer (which must be your employer) and
 * MbientLab Inc, (the "License").  You may not use this Software unless you
 * agree to abide by the terms of the License which can be found at
 * www.mbientlab.com/terms.  The License limits your use, and you acknowledge,
 * that the Software may be modified, copied, and distributed when used in
 * conjunction with an MbientLab Inc, product.  Other than for the foregoing
 * purpose, you may not use, reproduce, copy, prepare derivative works of,
 * modify, distribute, perform, display or sell this Software and/or its
 * documentation for any purpose.
 *
 * YOU FURTHER ACKNOWLEDGE AND AGREE THAT THE SOFTWARE AND DOCUMENTATION ARE
 * PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTY OF MERCHANTABILITY, TITLE,
 * NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL
 * MBIENTLAB OR ITS LICENSORS BE LIABLE OR OBLIGATED UNDER CONTRACT, NEGLIGENCE,
 * STRICT LIABILITY, CONTRIBUTION, BREACH OF WARRANTY, OR OTHER LEGAL EQUITABLE
 * THEORY ANY DIRECT OR INDIRECT DAMAGES OR EXPENSES INCLUDING BUT NOT LIMITED
 * TO ANY INCIDENTAL, SPECIAL, INDIRECT, PUNITIVE OR CONSEQUENTIAL DAMAGES, LOST
 * PROFITS OR LOST DATA, COST OF PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY,
 * SERVICES, OR ANY CLAIMS BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY
 * DEFENSE THEREOF), OR OTHER SIMILAR COSTS.
 *
 * Should you have any questions regarding your right to use this Software,
 * contact MbientLab via email: hello@mbientlab.com
 */

import CoreBluetooth
import Combine

public extension MetaWearScanner {
    static let shared = MetaWearScanner()
    static let sharedRestore = MetaWearScanner(restoreIdentifier: "MetaWearScanner.shared")
}

/// Start scanning for MetaWear devices without having to understand all of CoreBluetooth. Pipelines return on the scanner's unique `bleQueue`.
///
public class MetaWearScanner: NSObject {

    // MARK: - Discovered Devices

    /// All MetaWears discovered by the `CBCentralManager`. Read only on the `bleQueue`.
    public private(set) var deviceMap: [UUID: MetaWear] = [:]

    /// Publishes the `deviceMap` after adding a new member.
    public private(set) lazy var discoveredDevices: AnyPublisher<[UUID: MetaWear], Never> = _makeDiscoveredDevicesPublisher()

    /// Publishes only newly discovered `MetaWear` (from `centralManager(:didDiscover:advertisementData:rssi:)`)
    public private(set) lazy var didDiscoverUniqued: AnyPublisher<MetaWear, Never> = _makeDidDiscoverUniquedPublisher()

    /// Publishes any `MetaWear` discovery (from `centralManager(:didDiscover:advertisementData:rssi:)`)
    public private(set) lazy var didDiscover: AnyPublisher<MetaWear, Never> = _makeDidDiscoverPublisher()


    // MARK: - Scanning State

    /// Stream of `CBCentralManager.state` updates, such as for authorization or power status. (from `centralManagerDidUpdateState`)
    public private(set) lazy var centralManagerDidUpdateState: AnyPublisher<CBManagerState, Never> = _makeCentralDidUpdatePublisher()

    /// Filtered and failing stream of `CBCentralManager.state` updates. Skips unknown and resetting states changes, but publishes powerOn and fails on power off, unsupported, and unauthorized.
    public private(set) lazy var centralManagerFilteredDidUpdateState: AnyPublisher<CBManagerState, MetaWearError> = _makeFilteredCentralDidUpdatePublisher()

    /// Whether or not the scanner's CBCentralManager is scanning.
    public var isScanning: Bool { self.central.isScanning }


    // MARK: - Bluetooth API Queue and CBCentralManager

    /// Queue used by the `CBCentralManager` for all BLE operations and reads. All pipelines return on this queue.
    public let bleQueue: DispatchQueue
    public private(set) var central: CBCentralManager! = nil

    /// Provide a restore identifier if desired. Call `retrieveSavedMetaWears` and then `startScan` to gather remembered MetaWears and newly discovered nearby MetaWears (once Bluetooth is powered on).
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

    /// Start the scanning process for MetaWear or MetaBoot devices. Discovered devices are delivered by the `didDiscover` publisher.
    /// - Parameter allowDuplicates: An Apple API that increases performance at expense of battery life
    ///
    func startScan(allowDuplicates: Bool) {
        runWhenPoweredOn {
            self.central.scanForPeripherals(
                withServices: [.metaWearService, .metaWearDfuService],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
            )

            // Restart scanning if BLE state toggles off then on
            self.runOnPowerOff.append { [unowned self] in
                self.startScan(allowDuplicates: allowDuplicates)
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

    /// Unsorted list of devices stored via `MetaWear.remember()`.
    /// - Returns: Publisher that completes only when `CBCentralManager` is `.poweredOn`.
    ///
    func retrieveSavedMetaWears() -> AnyPublisher<[MetaWear],Never> {
        runWhenPoweredOn { [weak self] promise in
            guard let self = self else { return }

            let devices = self.central
                .retrievePeripherals(withIdentifiers: UserDefaults._getRememberedUUIDs())
                .map { peripheral -> MetaWear in
                    let device = self.deviceMap[peripheral.identifier] ?? MetaWear(peripheral: peripheral, scanner: self)
                    self.deviceMap[peripheral.identifier] = device
                    return device
                }

            promise(.success(devices))
        }
    }

    /// Unsorted list of devices that are already connected, which is useful to check after state was restored.
    /// - Returns: Publisher that completes only when `CBCentralManager` is `.poweredOn`.
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
    func getMetaWear(id: UUID) -> MetaWear {
        var metawear: MetaWear!
        bleQueue.sync {
            guard let device = deviceMap[id]
            else { fatalError("Requested a device that does not exist.") }
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
            deviceMap.forEach { $0.value._scannerDidDisconnectPeripheral(error: MetaWearError.bluetoothPoweredOff) }
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

internal extension MetaWearScanner {

    func connect(_ device: MetaWear?) {
        runWhenPoweredOn { [weak device] in
            guard let device = device else { return }
            self.central.connect(device.peripheral)
        }
    }

    func cancelConnection(_ device: MetaWear) {
        runWhenPoweredOn {
            self.central.cancelPeripheralConnection(device.peripheral)
        }
    }

    /// Add this device to a persistent list loaded by `.retrieveSavedMetaWears()`
    ///
    func remember(_ device: MetaWear) {
        let idString = device.peripheral.identifier.uuidString
        var devices = UserDefaults._getRememberedUUIDStrings()
        if !devices.contains(idString) {
            devices.append(idString)
        }
        UserDefaults._save(uuidStrings: devices)
    }

    /// Remove this device from the persistent list loaded by `.retrieveSavedMetaWears()`
    ///
    func forget(_ device: MetaWear) {
        var devices = UserDefaults._getRememberedUUIDStrings()
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

    func _makeFilteredCentralDidUpdatePublisher() -> AnyPublisher<CBManagerState, MetaWearError> {
        didUpdateStateSubject
            .tryCompactMap({ state in
                switch state {
                    case .unknown: fallthrough
                    case .resetting: return nil // Updates are imminent, so provide a skippable nil
                    case .unsupported: throw MetaWearError.bluetoothUnsupported
                    case .unauthorized: throw MetaWearError.bluetoothUnauthorized
                    case .poweredOff: throw MetaWearError.bluetoothPoweredOff
                    case .poweredOn: return .poweredOn
                    @unknown default: fatalError("MetaWear: New central.state values, please update.")
                }
            })
            .mapError { $0 as! MetaWearError }
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

// MARK: - Persistence

fileprivate extension UserDefaults {

    static private let _rememberedDevicesKey = "com.mbientlab.rememberedDevices"

    static func _getRememberedUUIDStrings() -> [String] {
        UserDefaults.standard.stringArray(forKey: UserDefaults._rememberedDevicesKey) ?? []
    }

    static func _getRememberedUUIDs() -> [UUID] {
        _getRememberedUUIDStrings().compactMap(UUID.init(uuidString:))
    }

    static func _save(uuidStrings: [String]) {
        UserDefaults.standard.set(uuidStrings, forKey: UserDefaults._rememberedDevicesKey)
    }
}
