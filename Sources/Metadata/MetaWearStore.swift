// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear
import Combine

public typealias MWKnownDevice = (mw: MetaWear?, meta: MetaWear.Metadata)

/// Stores all groups, known devices, and unknown devices merged from persistence and MetaWearScanner/CoreBluetooth. Retrieves devices from the scanner if detected. While each Apple device provides a Bluetooth accessory with a unique identifier, those UUIDs are not stable between a user's devices. This store maps stable MetaWear identifiers to those UUIDs so that metadata changes, such as a device's name or grouping, on any user device will synchronize between devices.
///
public class MetaWearStore {

    /// Loads persisted device metadata and requests those devices
    /// from CoreBluetooth (after the linked scanner is powered on).
    ///
    public func load() throws {
        try loader.load()
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

    /// Queue used by scanner and MetaWears for all Bluetooth operations
    ///
    public var bleQueue: DispatchQueue { scanner.bleQueue }

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
        self.update(for: scanner.discoveredDevicesPublisher)

        _knownDevices.sink { update in
            print("_known", update.map(\.key))
        }
        .store(in: &subs)

        _unknownDevices.sink { update in
            print("_unknown", update)
        }
        .store(in: &subs)
    }

    // Internal details
    private unowned let scanner:   MetaWearScanner
    private unowned let loader:    MWKnownDevicesPersistence
    private var subs             = Set<AnyCancellable>()
    private let _groups:           Subject<[UUID : MetaWear.Group]>
    private let _knownDevices:     Subject<[MACAddress : MetaWear.Metadata]>
    private let _unknownDevices:   Subject<Set<UUID>>
    private typealias Subject<T> = CurrentValueSubject<T,Never>

}

// MARK: - Public API - Subscribe to specific items

public extension MetaWearStore {

    /// Receive updates when the device's Metadata changes or the scanner discovers the device nearby.
    ///
    func publisher(for mac: MACAddress) -> AnyPublisher<MWKnownDevice, Never> {

        /// Retrieve a known or recently forgotten MetaWear and its metadata (or best representation)
        let known = getDeviceAndMetadata(mac)
        let localID = known?.mw?.peripheral.identifier

        let metawear: AnyPublisher<MetaWear?, Never> = scanner.discoveredDevicesPublisher
            .compactMap { [weak self] dict -> MetaWear? in

                // Return a MetaWear already discovered at kickoff
                if let localID = localID { return dict[localID] }

                // If it wasn't discovered at kickoff, find it if discovered since then
                let localIDs = self?._knownDevices.value[mac]?.localBluetoothIds ?? []
                for id in localIDs {
                    if let metawear = dict[id] { return metawear }
                }

                // Shouldn't be reached, but handle the case the where the MetaWear was just forgotten this session
                guard mac.isEmpty == false else { return nil }
                return dict.first(where: { $0.value.info.mac == mac })?.value
            }
            .removeDuplicates()
            .eraseToAnyPublisher()

        let metadata = _knownDevices
            .compactMap { dict -> MetaWear.Metadata? in dict[mac] }
            .removeDuplicates()

        let forcedMetaWearKickoff = Just(known?.mw).merge(with: metawear)

        return Publishers.CombineLatest(forcedMetaWearKickoff, metadata)
            .map { ($0, $1) }
            .subscribe(on: bleQueue)
            .eraseToAnyPublisher()
    }

    /// Receive updates when the group's identity changes or when the scanner discovers any member devices nearby.
    ///
    func publisher(for group: MetaWear.Group) -> AnyPublisher<(group: MetaWear.Group, devices: [MWKnownDevice]), Never> {

        let groupUpdates = _groups
            .compactMap { dict -> MetaWear.Group? in dict[group.id] }
            .removeDuplicates()

        let knownDevicesUpdates = scanner.discoveredDevicesPublisher
            .compactMap { [weak self] devices -> (devices: [CBPeripheralIdentifier: MetaWear], group: MetaWear.Group)? in
                guard let group = self?.getGroup(id: group.id) else { return nil }
                return (devices, group)
            }
            .map { [weak self] devices, group -> [MWKnownDevice] in
                group.deviceMACs.reduce(into: [MWKnownDevice]()) { result, mac in
                    guard let metadata = self?._knownDevices.value[mac] else { return }
                    let localID = metadata.localBluetoothIds.first(where: { devices[$0] != nil })
                    let metawear = localID != nil ? devices[localID!] : devices.first(where: { $0.value.info.mac == mac && mac.isEmpty == false })?.value
                    result.append((metawear, metadata))
                }
            }
            .removeDuplicates { prior, new in
                prior.map(\.mw) == new.map(\.mw)
            }

        let forcedKnownDevicesKickoff = Just(getDevicesInGroup(group)).merge(with: knownDevicesUpdates)

        return Publishers.CombineLatest(groupUpdates, forcedKnownDevicesKickoff)
            .map { ($0, $1) }
            .subscribe(on: bleQueue)
            .eraseToAnyPublisher()
    }
}

// MARK: - Public API - Retrieve Items

public extension MetaWearStore {

    /// Retrieve a reference for a device by MAC address.
    ///
    /// If ``forget(locally:)`` or ``forget(globally:)`` was called
    /// on the device this session, `DeviceInformation` still exists
    /// on the MetaWear instance and the device will be retrieved,
    /// even though the local CoreBluetooth UUID is not associated
    /// with metadata in ``knownDevices``.
    ///
    /// - Parameter device: Targeted device
    /// - Returns: Reference to the device, if available from the scanner
    ///
    func getDevice(_ device: MetaWear.Metadata) -> MetaWear? {
        var metawear: MetaWear? = nil
        bleQueue.sync {
            for id in device.localBluetoothIds {
                if let mw = scanner.discoveredDevices[id] {
                    metawear = mw
                    break
                }
            }
        }
        // Try to retrieve a recently forgotten device by MAC
        return metawear ?? _getMetaWearBy(mac: device.mac)
    }

    /// Retrieve a reference and metadata for a device by MAC address.
    ///
    /// If ``forget(locally:)`` or ``forget(globally:)`` was called
    /// on the device this session, `DeviceInformation` still exists
    /// on the MetaWear instance and the device will be retrieved,
    /// even though the local CoreBluetooth UUID is not associated
    /// with metadata in ``knownDevices``.
    ///
    /// - Parameter device: Targeted device
    /// - Returns: Reference to the device, if available from the scanner
    ///
    func getDeviceAndMetadata(_ mac: MACAddress) -> MWKnownDevice? {
        if let metadata = _knownDevices.value[mac] {
            return (getDevice(metadata), metadata)

            // Retrieve as much info as possible from a recently forgotten MetaWear
        } else if mac.isEmpty == false,
                  let metawear = _getMetaWearBy(mac: mac) {
            return (metawear, .init(mac: metawear.info.mac,
                                    serial: metawear.info.serialNumber,
                                    model: metawear.info.model,
                                    modules: [:],
                                    localBluetoothIds: [metawear.localBluetoothID],
                                    name: metawear.name))
        }
        return nil
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

    /// Using a local UUID, retrieves a MetaWear and any related cloud-synced metadata.
    ///
    /// If a device was recently forgotten, metadata still exists on the MetaWear instance and
    /// some of it is recovered and returned here (except for module information).
    ///
    /// - Parameter byLocalCBUUID: A MetaWear's local CBPeripheral.identifier
    /// - Returns: Device reference from the MetaWearScanner and related Metadata, if available
    ///
    func getDevice(byLocalCBUUID: CBPeripheralIdentifier) -> (device: MetaWear?, metadata: MetaWear.Metadata?) {
        var metawear: MetaWear? = nil
        bleQueue.sync {
            metawear = scanner.discoveredDevices[byLocalCBUUID]
        }

        var metadata = _knownDevices.value.values.first(where: { $0.localBluetoothIds.contains(byLocalCBUUID) } )
        // Retrieve as much info as possible from a recently forgotten MetaWear
        if metadata == nil, let metawear = metawear, metawear.info.mac.isEmpty == false {
            metadata = .init(mac: metawear.info.mac,
                             serial: metawear.info.serialNumber,
                             model: metawear.info.model,
                             modules: [:],
                             localBluetoothIds: [], // Sign that it is not known
                             name: metawear.name)
        }
        return (metawear, metadata)
    }

    /// To confirm whether the device is synced in known devices, useful
    /// for edge case UIs where you wish to display a synced symbol
    /// on a device subject to ``forget(locally:)`` this session
    ///
    func deviceIsCloudSynced(mac: MACAddress) -> Bool {
        guard mac.isEmpty == false, mac.contains("Unkown") == false else { return false }
        var isSyncedInKnownDevices = false
        bleQueue.sync {
            isSyncedInKnownDevices = _knownDevices.value[mac] != nil
        }
        return isSyncedInKnownDevices
    }

    /// Get a grouping of MetaWears by the group's id
    ///
    func getGroup(id: UUID) -> MetaWear.Group? {
        _groups.value[id]
    }
}


// MARK: - Public API - Edit Items

public extension MetaWearStore {

    /// Add a MetaWear grouping
    ///
    func add(group: MetaWear.Group) {
        bleQueue.async { [weak self] in
            self?._groups.value[group.id] = group
        }
    }

    /// Update values for a group
    /// - Parameter group: Group of MetaWear(s)
    ///
    func update(group: MetaWear.Group) {
        bleQueue.async { [weak self] in
            self?._groups.value[group.id] = group
        }
    }

    /// Rename a MetaWear grouping
    ///
    func rename(group: MetaWear.Group, to newName: String) {
        bleQueue.async { [weak self] in
            self?._groups.value[group.id, default: group].name = newName
        }
    }

    /// Remove a MetaWear grouping across all devices
    ///
    func remove(group: UUID) {
        bleQueue.async { [weak self] in
            self?._groups.value.removeValue(forKey: group)
        }
    }

    /// Update values for a known device both in metadata and advertising packets
    ///
    func rename(known: MetaWear.Metadata, to newName: String) throws {
        let command = try MWChangeAdvertisingName(newName: newName)
        let device = getDevice(known)

        bleQueue.async { [weak self] in
            /// Rename in metadata
            var edited = known
            edited.name = newName
            self?._knownDevices.value[known.id] = edited

            /// Rename in advertisements
            guard let device = device, let self = self else { return }
            device.publishWhenConnected()
                .command(command)
                .sink { _ in } receiveValue: { _ in }
                .store(in: &self.subs)
        }
    }
}


// MARK: - Public API - Add / Remove

public extension MetaWearStore {

    /// Removes this device from memory, including its presence in any groups,
    /// across all iCloud-synced devices. Emptied groups will be disbanded.
    ///
    /// - Parameter metawear: Previously remembered device
    ///
    func forget(globally metawear: MetaWear.Metadata) {
        self.forget(locally: metawear)

        bleQueue.async { [weak self] in
            guard let self = self else { return }

            self._knownDevices.value.removeValue(forKey: metawear.mac)

            // Remove from groups, remove any empty groups
            var didEditGroups = false
            let editedGroups = self._groups.value.compactMapValues { group -> MetaWear.Group? in
                guard group.deviceMACs.contains(metawear.mac) else { return group }
                didEditGroups = true
                var edited = group
                edited.deviceMACs.remove(metawear.mac)
                return edited.deviceMACs.isEmpty ? nil : edited
            }
            if didEditGroups { self._groups.value = editedGroups }
        }
    }

    /// Removes this device from memory, including its presence in any groups,
    /// just for this current machine. Emptied groups will be disbanded.
    /// - Parameter metadata: For previously remembered device
    ///
    func forget(locally metadata: MetaWear.Metadata) {
        let device = getDevice(metadata)

        bleQueue.async { [weak self] in
            var localID: CBPeripheralIdentifier? = nil

            // Remove local memory (i.e., will not be requested next app launch)
            if let device = device {
                // Cache local CoreBluetooth ID
                localID = device.localBluetoothID
                device.forget()
            }

            // Remove local id from metadata, remove if empty
            if var known = self?._knownDevices.value[metadata.mac], let localID = localID {
                known.localBluetoothIds.remove(localID)
                if known.localBluetoothIds.isEmpty { self?._knownDevices.value.removeValue(forKey: metadata.mac) }
                else { self?._knownDevices.value[metadata.mac] = known }
                self?._unknownDevices.value.insert(localID)
            }
        }
    }

    /// Saves template metadata for a discovered, but not yet connected device.
    /// - Parameter unknown: Previously remembered device
    /// - Parameter didAdd: Callback after the device's metadata is obtained
    ///                     and matched/autofilled against persisted devices
    ///
    ///
    func connectAndRemember(unknown: CBPeripheralIdentifier, didAdd: ((MWKnownDevice) -> Void)? = nil) {
        bleQueue.async { [weak self] in
            guard let self = self else { return }
            guard self._unknownDevices.value.contains(unknown),
                  let metawear = self.scanner.discoveredDevices[unknown]
            else { return }

            self.makeFirstMetadata(for: metawear) { [weak metawear, weak self] newMetadata in
                guard let self = self else { return }
                self._unknownDevices.value.remove(unknown)
                didAdd?((metawear, newMetadata))
            }
        }
    }
}

// MARK: - Internal Details

private extension MetaWearStore {

    /// Receives updates from `MetaWearScanner` when its device map changes with devices
    /// locally persisted or presently discovered. This method updates `_knownDevices`
    /// and `_unknownDevices` to reflect all devices that do or don't match a
    /// known local UUID identifier.
    ///
    /// Note this may lead to duplication of a locally forgotten device, but where a
    /// cloud record for other machines still exists. Reconnection to such a device will
    /// "merge" it back into the known devices list. If locally forgotten during this session,
    /// this `update` function will not be called (as it already is discovered) and the
    /// `MetaWear` already instantiated will still maintain its `info` struct with, at minimum,
    /// its MAC address.
    ///
    /// Some scanner updates may discover known devices, but not unknown devices. For
    /// objects that need to obtain a reference to the initialized `MetaWear` of the
    /// just-discovered known device, use ``publisher(for:)-78tdx``. In these cases,
    /// this function will not diff the `_knownDevices` dictionary because it will
    /// already have been populated by loading persisted data.
    ///
    func update(for discoveries: AnyPublisher<[CBPeripheralIdentifier : MetaWear], Never>) {
        discoveries.map(\.keys)
            .compactMap { [weak self] cbuuids -> Set<CBPeripheralIdentifier>? in
                guard let self = self else { return nil }

                let currentUnknowns = Set(self._unknownDevices.value)

                let currentKnownUUIDs = self._knownDevices.value.reduce(into: Set<CBPeripheralIdentifier>()) {
                    $0.formUnion($1.value.localBluetoothIds)
                }

                /// Remove from old unknowns any currently known local UUIDs (rare case)
                var newUnknowns = currentUnknowns.subtracting(currentKnownUUIDs)

                // For any (possibly new) discoveries, add to newUnknowns any that don't match a known ID
                for id in cbuuids {
                    if currentKnownUUIDs.contains(id) == false {
                        newUnknowns.insert(id)
                    }
                }

                return newUnknowns == currentKnownUUIDs ? nil : newUnknowns
            }
            .sink { [weak self] unknownIdentifiers in
                self?._unknownDevices.send(unknownIdentifiers)
            }
            .store(in: &subs)
    }

    /// Updates the `_knownDevices`, `_groups` and `_unknownDevices` maps to reflect
    /// persisted state from a local or cloud source.
    ///
    func update(for loader: AnyPublisher<MWKnownDevicesLoadable, Never>) {
        loader
            .sink { [ weak self] loaded in
                guard let self = self else { return }

                print(#function, loaded.devices.map(\.name))

                /// Adopt the latest data wholesale (written only by loader + user interaction)
                self._groups.value = loaded.groups.dictionary()
                self._knownDevices.value = loaded.devices.dictionary()

                /// At this time, `_unknownDevices` may be populated by the `MetaWearScanner` by:
                /// (a) discovery
                /// (b) populating from a UserDefaults request.
                ///
                /// For (a), the MAC is not available and these are truly unknown.
                ///
                /// For (b), the MAC is stored in the `localPeripherals` UserDefaults key.
                /// When the MetaWear is initialized by the scanner, that key populates the MAC for an
                /// otherwise blank `info` struct (until first connection).
                ///
                /// If this session a user requested to forget a device, the MetaWear's `info` struct remains
                /// in the initialized MetaWear, but the the matching `_knownDevices` `Metadata` will not
                /// contain the local ID.
                ///
                /// To support UI that indicates the device is cloud synced but is not in the local
                /// "recognized short list", use ``getDeviceAndMetadata(_:)`` or ``getDevice(byLocalCBUUID:)``
                /// and flag "locally unknown" state be the presence of the local ID in the `Metadata` object.
                ///
                /// Filter out any previously unknown devices that are now recognized from
                /// persisted metadata.
                ///
                let latestKnownIDs = loaded.devices
                    .map(\.localBluetoothIds)
                    .reduce(into: Set<CBPeripheralIdentifier>()) { $0.formUnion($1) }

                self._unknownDevices.value = self._unknownDevices.value.subtracting(latestKnownIDs)
            }
            .store(in: &subs)
    }

    /// Mirrors changes to metadata for persistence.
    ///
    func persistChanges(to loader: MWKnownDevicesPersistence) {
        Publishers.CombineLatest(_groups, _knownDevices)
        // Otherwise blanks or local will overwrite cloud immediately
            .dropFirst(1)
            .map { groups, known in MWKnownDevicesLoadable(groups: Array(groups.values), devices: Array(known.values)) }
            .sink { _ in } receiveValue: { [weak self] in
                print("Persisting", $0.devices.map(\.name))
                do {
                    try self?.loader.save($0)
                } catch { NSLog("Metawear Metadata Save Failed: \(error.localizedDescription)") }
            }
            .store(in: &subs)
    }

    /// Obtain a MetaWear by MAC address in a queue safe manner from the MetaWearScanner
    func _getMetaWearBy(mac: MACAddress) -> MetaWear? {
        var metawear: MetaWear? = nil
        guard mac.isEmpty == false else { return nil }
        bleQueue.sync {
            metawear = scanner.discoveredDevices.first(where: { $0.value.info.mac == mac })?.value
        }
        return metawear
    }

    /// Refreshes Metadata for the given MetaWear,
    /// updating any persisted information matching that MAC address.
    ///
    func makeFirstMetadata(for metawear: MetaWear, didRefresh: ((MetaWear.Metadata) -> Void)? = nil) {
        metawear.publishWhenConnected()
            .first()
            .mapToMWError()
        /// Request module description async + zip with known post-connection identifiers
            .flatMap { metawear in
                Publishers.Zip(
                    metawear.describeModules(),
                    Just((
                        info: metawear.info,
                        localID: metawear.localBluetoothID,
                        adName: metawear.name
                    )).setFailureType(to: MWError.self)
                )
            }
        /// Make metadata from this
            .map { modules, ids -> MetaWear.Metadata in
                // An empty MAC never occur, but would be high-risk. Provide a stand-in identifier until refreshed.
                let mac = ids.info.mac.isEmpty == false
                ? ids.info.mac
                : "Unknown \(ids.localID.uuidString)"
                return .init(mac: mac,
                             serial: ids.info.serialNumber,
                             model: ids.info.model,
                             modules: modules,
                             localBluetoothIds: [ids.localID],
                             name: ids.adName
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

        if metawear.connectionState != .connected { metawear.connect() }
    }

}

// MARK: - Helpers

internal extension Publisher {

    /// Erase and share a publisher on the main queue.
    func shareOnMain() -> AnyPublisher<Output,Failure> {
        receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
}

extension UUID: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

public extension Array where Element == MetaWear.Group {
    func allDevicesMACAddresses() -> Set<String> {
        reduce(into: Set<String>()) { $0.formUnion($1.deviceMACs) }
    }
}
