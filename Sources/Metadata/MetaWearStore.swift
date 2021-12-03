// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear
import Combine

/// Stores all groups, known devices, and unknown devices merged from persistence and MetaWearScanner/CoreBluetooth. Retrieves devices from the scanner if detected. While each Apple device provides a Bluetooth accessory with a unique identifier, those UUIDs are not stable between a user's devices. This store maps stable MetaWear identifiers to those UUIDs so that metadata changes, such as a device's name or grouping, on any user device will synchronize between devices.
///
public class MetaWearStore {

    /// Loads persisted device metadata and requests those devices
    /// from CoreBluetooth (after the linked scanner is powered on).
    ///
    public func load() throws {
        try loader.load()
        scanner.retrieveSavedMetaWearsAsync()
    }

    /// All known devices, including those part of groups.
    /// If using iCloud persistence, this will include devices
    /// that this local host might not have encountered. Not sorted.
    ///
    /// Populated by `MWKnownDevicesPersistence`. Reduced by `forget`.
    ///
    public let knownDevices:     AnyPublisher<[MetaWear.Metadata],Never>

    /// Groupings of known devices. A device can be
    /// a member of multiple groups. Not sorted.
    ///
    /// Populated by `MWKnownDevicesPersistence`.
    ///
    public let groups:           AnyPublisher<[MetaWear.Group],Never>

    /// Devices discovered by a MetaWear scanner that the
    ///  local host has not connected to previously. The UUIDs
    ///  are the local CBPeripheral identifier. Not sorted.
    ///
    /// Populated by `MetaWearScanner` after checking against `knownDevices`.
    /// Reduced by using `remember` and expanded by using `forget`.
    ///
    public let unknownDevices:   AnyPublisher<Set<UUID>,Never>

    /// Known devices that are not part of any group.
    /// If using iCloud persistence, this will include
    /// devices that this local host might not have
    /// encountered. Not sorted.
    ///
    public let ungroupedDevices: AnyPublisher<[MetaWear.Metadata],Never>

    /// Call `.load()` to asynchronously load persisted MetaWear metadata
    /// and enqueue a request for those devices once the MetaWearScanner is
    ///  active. Be sure to connect to unknown devices through the store so
    ///   they may be properly registered.
    ///
    public init(scanner: MetaWearScanner, loader: MWKnownDevicesPersistence) {
        self.scanner = scanner
        self.loader = loader
        self._groups = .init([:])
        self._knownDevices = .init([:])
        self._unknownDevices = .init([])

        self.unknownDevices   = _unknownDevices.shareOnMain()
        self.knownDevices     = _knownDevices.mapValues().shareOnMain()
        self.groups           = _groups.mapValues().shareOnMain()
        self.ungroupedDevices = Publishers.CombineLatest(groups, knownDevices)
            .map { groups, known -> [MetaWear.Metadata] in
                let grouped = groups.allDevicesMACAddresses()
                return known.filter { grouped.contains($0.mac) == false }
            }
            .shareOnMain()

        self.persistChanges(to: loader)
        self.update(for: loader.metawears)
        self.update(for: scanner.discoveredDevices)
    }

    // Internal details
    private unowned let scanner:   MetaWearScanner
    private unowned let loader:    MWKnownDevicesPersistence
    private var subs             = Set<AnyCancellable>()
    private let _groups:           Subject<[UUID : MetaWear.Group]>
    private let _knownDevices:     Subject<[MWMACAddress : MetaWear.Metadata]>
    private let _unknownDevices:   Subject<Set<UUID>>
    private typealias Subject<T> = CurrentValueSubject<T,Never>

}

// MARK: - Public API Methods

public extension Array where Element == MetaWear.Group {
    func allDevicesMACAddresses() -> Set<String> {
        reduce(into: Set<String>()) { $0.formUnion($1.deviceMACs) }
    }
}

public typealias MWKnownDevice = (mw: MetaWear?, meta: MetaWear.Metadata)
public extension MetaWearStore {

    // MARK: - Retrieve

    /// Retrieve a reference for a device
    /// - Parameter device: Targeted device
    /// - Returns: Reference to the device, if available from the scanner
    ///
    func getDevice(_ device: MetaWear.Metadata) -> MetaWear? {
        for id in device.localBluetoothIds {
            if let metawear = scanner.getMetaWear(id: id) { return metawear }
        }
        return nil
    }

    /// Retrieve a reference and metadata for a device
    /// - Parameter device: Targeted device
    /// - Returns: Reference to the device, if available from the scanner
    ///
    func getDeviceAndMetadata(_ mac: String) -> MWKnownDevice? {
        guard let metadata = _knownDevices.value[mac] else { return nil }
        return (getDevice(metadata), metadata)
    }

    /// Update values for a group of MetaWear(s)
    /// - Parameter group: Group of MetaWear(s)
    /// - Returns: Tuple of a MetaWear instance (if available) and its relevant saved Metadata
    ///
    func getDevicesInGroup(_ group: MetaWear.Group) -> [MWKnownDevice] {
        group.deviceMACs.reduce(into: [MWKnownDevice]()) { result, mac in
            guard let metadata = _knownDevices.value[mac] else { return }
            let metawear = getDevice(metadata)
            result.append((metawear, metadata))
        }
    }

    /// Using a local CBUUID, retrieves cloud-synced metadata. Matching uses
    /// MAC addresses, which are only available after a first connection. Thus,
    /// for `unknownDevices`, which have not been previously connected, metadata
    /// retrieval will fail, even if this MetaWear has been used by other devices.
    ///
    /// - Parameter byLocalCBUUID: A MetaWear's local CBPeripheral.identifier
    /// - Returns: Device reference from the MetaWearScanner and related Metadata, if available
    ///
    func getDevice(byLocalCBUUID: CBPeripheralIdentifier) -> (device: MetaWear?, metadata: MetaWear.Metadata?) {
        let metawear = scanner.getMetaWear(id: byLocalCBUUID)
        let metadata = _knownDevices.value.values.first(where: { $0.localBluetoothIds.contains(byLocalCBUUID) } )
        return (metawear, metadata)
    }

    func getGroup(id: UUID) -> MetaWear.Group? {
        _groups.value[id]
    }

    // MARK: - Edit

    func add(group: MetaWear.Group) {
        _groups.value[group.id] = group
    }

    /// Update values for a group
    /// - Parameter group: Group of MetaWear(s)
    ///
    func update(group: MetaWear.Group) {
        _groups.value[group.id] = group
    }

    func remove(group: UUID) {
        _groups.value.removeValue(forKey: group)
    }

    /// Update values for a known device
    /// - Parameter known: Known device
    ///
    func rename(known: MetaWear.Metadata, to newName: String) throws {
        let command = try MWChangeAdvertisingName(newName: newName)

        var edited = known
        edited.name = newName
        _knownDevices.value[known.id] = edited

        guard let device = getDevice(known) else { return }
        device.publishWhenConnected()
            .command(command)
            .sink { _ in } receiveValue: { _ in }
            .store(in: &subs)
    }

    // MARK: - Add / Remove

    func forget(globally metawear: MetaWear.Metadata) {
        forget(locally: metawear)
        _knownDevices.value.removeValue(forKey: metawear.mac)

        // Remove from groups, remove any empty groups
        var didEditGroups = false
        let editedGroups = _groups.value.compactMapValues { group -> MetaWear.Group? in
            guard group.deviceMACs.contains(metawear.mac) else { return group }
            didEditGroups = true
            var edited = group
            edited.deviceMACs.remove(metawear.mac)
            return edited.deviceMACs.isEmpty ? nil : edited
        }
        if didEditGroups { _groups.value = editedGroups }
    }

    /// Removes this device from memory, including its presence in any groups.
    /// Emptied groups will be disbanded.
    /// - Parameter known: Previously remembered device
    ///
    func forget(locally metawear: MetaWear.Metadata) {
        // Cache local CoreBluetooth ID
        var localID: CBPeripheralIdentifier? = nil

        // Remove local memory (i.e., will not be requested next app launch)
        if let metawear = getDevice(metawear) {
            localID = metawear.peripheral.identifier
            scanner.forget(metawear)
        }

        // Remove local id from metadata, remove if empty
        if var known = _knownDevices.value[metawear.mac], let localID = localID {
            known.localBluetoothIds.remove(localID)
            if known.localBluetoothIds.isEmpty { _knownDevices.value.removeValue(forKey: metawear.mac) }
            else { _knownDevices.value[metawear.mac] = known }
        }
    }

    /// Saves template metadata for a discovered, but not yet connected device.
    /// - Parameter unknown: Previously remembered device
    /// - Parameter didAdd: Callback after the device's metadata is obtained
    ///                     and matched/autofilled against persisted devices
    ///
    ///
    func remember(unknown: CBPeripheralIdentifier, didAdd: ((MWKnownDevice) -> Void)? = nil) {
        guard _unknownDevices.value.contains(unknown),
              let metawear = scanner.getMetaWear(id: unknown)
        else { return }
        refreshMetadata(for: metawear) { [weak metawear, weak self] newMetadata in
            guard let self = self else { return }
            self._unknownDevices.value.remove(unknown)
            didAdd?((metawear, newMetadata))
        }
    }

    /// Refreshes Metadata for the given MetaWear,
    /// updating any persisted information matching that MAC address.
    ///
    func refreshMetadata(for metawear: MetaWear, didRefresh: ((MetaWear.Metadata) -> Void)? = nil) {
        metawear.publishWhenConnected()
            .first()
            .flatMap { metawear in
                Publishers.Zip3(
                    metawear.detectModules(),
                    metawear.readCharacteristic(.allDeviceInformation),
                    Just((localID: metawear.peripheral.identifier,
                          mac: metawear.mac,
                          adName: metawear.name
                         )).setFailureType(to: MWError.self)
                )
            }
            .map { modules, info, identifiers -> MetaWear.Metadata in
            .init(mac: identifiers.mac ?? "Unknown \(identifiers.localID.uuidString)",
                  serial: info.serialNumber,
                  model: info.modelNumber,
                  modules: modules,
                  localBluetoothIds: [identifiers.localID],
                  name: identifiers.adName
            )}
            .sink { completion in } receiveValue: { [weak self] refreshedData in
                guard let self = self else { return }
                var data = refreshedData
                if let existing = self._knownDevices.value[refreshedData.mac] {
                    data.localBluetoothIds.formUnion(existing.localBluetoothIds)
                    data.name = existing.name
                    if data.mac.contains("Unknown") {
                        data.mac = existing.mac
                    }
                }
                self._knownDevices.value[data.mac] = data
                didRefresh?(data)
            }
            .store(in: &subs)

        metawear.connect()
    }
}

// MARK: - Internal Details

private extension MetaWearStore {

    /// Updates the `_unknownDevices` dictionary to reflect all devices that don't match
    /// a known CBUUID.
    ///
    /// Receives a just-updated dictionary of devices from a CBCentralManager / scanner.
    /// Some may be discovered nearby, others loaded from memory.
    ///
    func update(for discoveries: AnyPublisher<[CBPeripheralIdentifier : MetaWear], Never>) {
        discoveries.map(\.keys)
            .compactMap { [weak self] cbuuids -> Set<CBPeripheralIdentifier>? in
                guard let self = self else { return nil }

                let knownCBUUIDs = self._knownDevices.value.reduce(into: Set<CBPeripheralIdentifier>()) {
                    $0.formUnion($1.value.localBluetoothIds)
                }
                let oldUnknowns = Set(self._unknownDevices.value)
                var newUnknowns = oldUnknowns.subtracting(knownCBUUIDs)

                for id in cbuuids {
                    if knownCBUUIDs.contains(id) == false {
                        newUnknowns.insert(id)
                    }
                }

                return newUnknowns == knownCBUUIDs ? nil : newUnknowns
            }
            .sink { [weak self] unknownIdentifiers in
                self?._unknownDevices.send(unknownIdentifiers)
            }
            .store(in: &subs)
    }

    /// Updates the `_knownDevices`, `_groups` and `_unknownDevices` maps to reflect
    /// persisted state from a local or cloud source.
    ///
    /// Receives a just-updated pair or arrays of persisted device metadata. Since
    /// updating the target Subjects will trigger persistence, be sure that the first
    /// local update would be skipped for persistence, as that would overwrite the cloud
    /// data with local data. (More careful diffing is not implemented.)
    ///
    func update(for loader: AnyPublisher<MWKnownDevicesLoadable, Never>) {
        loader
            .sink { [ weak self] in
                guard let self = self else { return }

                /// Adopt the latest data
                self._groups.value = $0.groups.dictionary()
                self._knownDevices.value = $0.devices.dictionary()

                /// Filter out any previously unknown devices that are now recognized from
                /// persisted metadata.
                let latestKnowns = $0.devices.map(\.localBluetoothIds).reduce(into: Set<CBPeripheralIdentifier>()) { $0.formUnion($1) }
                self._unknownDevices.value = self._unknownDevices.value.subtracting(latestKnowns)
            }
            .store(in: &subs)
    }


    /// Mirrors changes to metadata for persistence.
    ///
    func persistChanges(to loader: MWKnownDevicesPersistence) {
        Publishers.CombineLatest(_groups, _knownDevices)
            .dropFirst(3) // Otherwise blanks or local will overwrite cloud immediately
            .map { groups, known in MWKnownDevicesLoadable(groups: Array(groups.values), devices: Array(known.values)) }
            .sink { _ in } receiveValue: { [weak self] in
                do {
                    try self?.loader.save($0)
                } catch { NSLog("Metawear Metadata Save Failed: \(error.localizedDescription)") }
            }
            .store(in: &subs)
    }
}

// MARK: - Helpers

internal extension Publisher {

    /// Erase and share a publisher on the main queue.
    func shareOnMain() -> AnyPublisher<Output,Failure> {
        share().receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
}

extension UUID: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
