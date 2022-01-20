// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear
import Combine

// MARK: - Implementation details for the `MetaWearSyncStore` to simplify reading the long source for the Store.

internal extension MetaWearSyncStore {

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

    /// Updates the `_knownDevices`,  `_unknownDevices`, `_groups`,  and `_groupsRecoverable` maps to reflect
    /// persisted state from a local or cloud source.
    ///
    func update(for loader: AnyPublisher<MWKnownDevicesLoadable, Never>) {
        loader
            .sink { [ weak self] loaded in
                guard let self = self else { return }

                /// Adopt the latest data wholesale (written only by loader + user interaction)
                self._groups.value = loaded.groups.dictionary()
                self._knownDevices.value = loaded.devices.dictionary()
                self._groupsRecoverable.value  = loaded.groupsRecovery.dictionary()

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
    func persistChanges(to loader: MWLoader<MWKnownDevicesLoadable>) {
        Publishers.CombineLatest3(_groups, _knownDevices, _groupsRecoverable)
        // Otherwise blanks or local will overwrite cloud immediately
            .dropFirst(1)
            .map { groups, known, groupsRecoverable -> MWKnownDevicesLoadable in
                MWKnownDevicesLoadable(
                    devices: Array(known.values),
                    groups: Array(groups.values),
                    groupsRecovery: Array(groupsRecoverable.values)
                )
            }
            .sink { _ in } receiveValue: { [weak self] in
                do {
                    try self?.loader.save($0)
                } catch {
                    NSLog("Metawear Metadata Save Failed: \(error.localizedDescription)")
                }
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
    func makeFirstMetadata(for metawear: MetaWear, didRefresh: ((MetaWearMetadata) -> Void)? = nil) {
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
            .map { modules, ids -> MetaWearMetadata in
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
