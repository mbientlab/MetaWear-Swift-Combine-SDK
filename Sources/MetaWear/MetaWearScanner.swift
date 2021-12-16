// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import Combine

public extension MetaWearScanner {
    static let shared = MetaWearScanner()
    static let sharedRestore = MetaWearScanner(restoreIdentifier: "MetaWearScanner.shared")
}

/// Start scanning for MetaWear devices without having to understand all of CoreBluetooth. Pipelines return on the scanner's unique `bleQueue`.
///
/// You may prefer to import `MetaWearMetaData` and use the `MetaWearStore` for its iCloud-synced metadata handling, instead of interactive with the scanner directly to obtain MetaWears.
///
public class MetaWearScanner: NSObject {

    // MARK: - Discovered Devices

    /// All MetaWears discovered by the `CBCentralManager`,
    ///  including those nearby but never connected to or those
    ///  not nearby but remembered by CoreBluetooth from a prior
    ///  session. Read only on the ``bleQueue``.
    ///
    @objc dynamic public private(set) var discoveredDevices: [CBPeripheralIdentifier: MetaWear] = [:]

    /// Publishes ``discoveredDevices`` after changes (e.g., adding a new member).
    ///
    public private(set) var discoveredDevicesPublisher: AnyPublisher<[CBPeripheralIdentifier: MetaWear], Never>!

    /// Publishes only newly discovered `MetaWear` from
    /// ``centralManager(_:didDiscover:advertisementData:rssi:)``
    ///
    public private(set) var didDiscoverUniqued: AnyPublisher<MetaWear, Never>!

    /// Publishes any `MetaWear` discovery from
    /// ``centralManager(_:didDiscover:advertisementData:rssi:)``
    ///
    public private(set) var didDiscover: AnyPublisher<MetaWear, Never>!


    // MARK: - Scanning State

    /// Stream of `CBCentralManager.state` updates,
    /// such as for authorization or power status.
    /// (from ``centralManagerDidUpdateState(_:)``).
    /// Skips unknown and resetting states changes.
    ///
    public private(set) var centralManagerDidUpdateState: AnyPublisher<CBManagerState, Never>!

    /// Whether or not the scanner's CBCentralManager is scanning.
    ///
    public var isScanning: Bool { self.central.isScanning }

    /// Updates for the scanner's CBCentralManager activity state.
    ///
    public private(set) var isScanningPublisher: AnyPublisher<Bool,Never>!


    // MARK: - Bluetooth API Queue and CBCentralManager

    /// Queue used by the ``central`` for all
    /// BLE operations and reads. All pipelines return
    /// on this queue.
    public let bleQueue: DispatchQueue

    /// CoreBluetooth manager instantiated by this scanner
    public private(set) var central: CBCentralManager!

    /// To start scanning for devices, call ``startScan(higherPerformanceMode:)``
    /// to gather remembered and nearby MetaWears once Bluetooth is powered on.
    ///
    /// To track Bluetooth state (e.g., authorized or disabled), use ``centralManagerDidUpdateState``.
    ///
    public init(restoreIdentifier: String? = nil,
                showPoweredOffAlert: Bool = true) {
        self.bleQueue = .makeScannerQueue()
        super.init()

        _makeCentralManager(with: restoreIdentifier, showPowerAlert: showPoweredOffAlert)
        setupPublishers()
        _retrieveSavedMetaWears()
    }

    func setupPublishers() {
        func share<P: Publisher>(_ publisher: P) -> AnyPublisher<P.Output, P.Failure> {
            publisher
                .subscribe(on: bleQueue)
                .share()
                .eraseToAnyPublisher()
        }

        self.centralManagerDidUpdateState = didUpdateStateSubject
            .merge(with: Just(central.state))
            .filtered()
            .erase(subscribeOn: bleQueue)

        self.isScanningPublisher = share(central.publisher(for: \.isScanning))
        self.discoveredDevicesPublisher = share(publisher(for: \.discoveredDevices))
        self.didDiscoverUniqued = share(didDiscoverMetaWearsUniquedSubject)
        self.didDiscover = share(didDiscoverMetaWearsSubject)
    }

    // Internal
    private var runOnPowerOn: [() -> Void] = []
    private var runOnPowerOff: [() -> Void] = []
    private var didUpdateStateSubject = CurrentValueSubject<CBManagerState,Never>(.poweredOff)
    private var didDiscoverMetaWearsSubject = PassthroughSubject<MetaWear,Never>()
    private var didDiscoverMetaWearsUniquedSubject = PassthroughSubject<MetaWear,Never>()
}

// MARK: - Public API — Scan / Retrieve Connected MetaWears

public extension MetaWearScanner {

    /// Start the scanning process for MetaWear or MetaBoot
    /// devices. Discovered devices are delivered by the
    /// ``MetaWearScanner/discoveredDevices`` publisher.
    /// - Parameter higherPerformanceMode: An Apple API that
    /// increases performance at expense of battery life
    /// (called `allowDuplicates`)
    ///
    func startScan(higherPerformanceMode: Bool) {
        _runWhenPoweredOn {
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
        _runWhenPoweredOn {
            self.central.stopScan()
        }
    }

    /// Unsorted list of devices that are already connected,
    /// which is useful to check after state was restored.
    /// - Returns: Publisher that completes only when
    ///  `CBCentralManager` is `.poweredOn`.
    ///
    func retrieveConnectedMetaWears() -> AnyPublisher<[MetaWear],Never> {
        _runWhenPoweredOn { [weak self] promise in
            guard let self = self else { return }
            let remembered = UserDefaults.MetaWear.loadLocalDevices()
            let services = [CBUUID.metaWearService, .metaWearDfuService]
            let devices = self.central.retrieveConnectedPeripherals(withServices: services)
                .map { peripheral -> MetaWear in
                    let device = self.discoveredDevices[peripheral.identifier] ??
                    MetaWear(
                        peripheral: peripheral,
                        scanner: self,
                        mac: remembered[peripheral.identifier]
                    )
                    self.discoveredDevices[peripheral.identifier] = device
                    return device
                }

            promise(.success(devices))
        }
    }

}


// MARK: - Internal — CBCentralManagerDelegate

extension MetaWearScanner: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // TODO: - This seems like an iOS bug.  If bluetooth powers off the
        // peripherals disconnect, but we don't get a deviceDidDisconnect callback.
        if central.state != .poweredOn {
            discoveredDevices.forEach { $0.value._scannerDidDisconnectPeripheral(error: MWError.bluetoothPoweredOff) }
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

        if let device = discoveredDevices[peripheral.identifier] {
            device._scannerDidDiscover(advertisementData: advertisementData, rssi: RSSI)
            didDiscoverMetaWearsSubject.send(device)

        } else {
            let device = MetaWear(peripheral: peripheral, scanner: self)
            discoveredDevices[peripheral.identifier] = device
            device._scannerDidDiscover(advertisementData: advertisementData, rssi: RSSI)

            didDiscoverMetaWearsSubject.send(device)
            didDiscoverMetaWearsUniquedSubject.send(device)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        discoveredDevices[peripheral.identifier]?._scannerDidConnect()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        discoveredDevices[peripheral.identifier]?._scannerDidFailToConnect(error: error)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        discoveredDevices[peripheral.identifier]?._scannerDidDisconnectPeripheral(error: error)
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
            self.discoveredDevices[peripheral.identifier] = MetaWear(peripheral: peripheral, scanner: self)
        }
    }
}

// MARK: - Internal — Connection

extension MetaWearScanner {

    internal func connect(_ device: MetaWear?) {
        _runWhenPoweredOn { [weak device] in
            guard let device = device else { return }
            self.central.connect(device.peripheral)
        }
    }

    internal func cancelConnection(_ device: MetaWear) {
        _runWhenPoweredOn {
            self.central.cancelPeripheralConnection(device.peripheral)
        }
    }
}

// MARK: - Internal – Setup

private extension MetaWearScanner {

    /// Populates the scanner's device map with those
    /// stored via ``MetaWear/MetaWear/remember()``.
    /// Runs after `CBCentralManager` is `.poweredOn`.
    ///
    func _retrieveSavedMetaWears() {
        _runWhenPoweredOn { [weak self] in
            guard let self = self else { return }
            let remembered = UserDefaults.MetaWear.loadLocalDevices()
            self.central
                .retrievePeripherals(withIdentifiers: remembered.map(\.key))
                .forEach { peripheral in
                    let device = self.discoveredDevices[peripheral.identifier] ??
                    MetaWear(
                        peripheral: peripheral,
                        scanner: self,
                        mac: remembered[peripheral.identifier]
                    )
                    self.discoveredDevices[peripheral.identifier] = device
                }
        }
    }

    func _makeCentralManager(with restoreIdentifier: String?, showPowerAlert: Bool) {
        var options: [String:Any] = [:]
        options[CBCentralManagerOptionShowPowerAlertKey] = showPowerAlert ? 1 : 0
        if let id = restoreIdentifier {
            options[CBCentralManagerOptionRestoreIdentifierKey] = id
        }
        self.central = CBCentralManager(delegate: self, queue: bleQueue, options: options)
    }

    func _runWhenPoweredOn(_ code: @escaping () -> Void) {
        bleQueue.async {
            if self.central.state == .poweredOn { code() }
            else { self.runOnPowerOn.append(code) }
        }
    }

    /// Executes a closure on the BLE queue **after** subscription and **after** the scanner is powered on.
    func _runWhenPoweredOn<O>(promise: @escaping ((Result<O,Never>) -> Void) -> Void) -> AnyPublisher<O,Never> {
        Deferred { [weak self] in Future<O,Never> { [weak self] future in
            self?.bleQueue.async {
                if self?.central.state == .poweredOn { promise(future) }
                else { self?.runOnPowerOn.append( { promise(future) } ) }
            }
        }}.eraseToAnyPublisher()
    }
}

internal extension Publisher where Output == CBManagerState, Failure == Never {
    func filtered() -> AnyPublisher<Output,Failure> {
        compactMap { state in
            switch state {
                case .resetting: return nil // Updates are imminent
                case .unknown: return nil
                default: return state
            }
        }
        .eraseToAnyPublisher()
    }
}
