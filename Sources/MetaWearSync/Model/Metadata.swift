// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear

/// Semi-permanent identifying information for a MetaWear across Apple devices.
///
/// - Warning: Do not depend on `Codable` conformance for persistence.
///            This conformance is intended only for in-memory drag and drop.
///
public struct MetaWearMetadata: Identifiable, Codable {
    /// Identified by MAC address
    public var id: String { mac }
    public var mac: MACAddress
    public var serial: String
    public var model: MetaWear.Model
    public var modules: [MWModules.ID:MWModules]

    public var localBluetoothIds: Set<CBPeripheralIdentifier>
    public var name: String

    public init(mac: String,
                serial: String,
                model: MetaWear.Model,
                modules: [MWModules.ID:MWModules],
                localBluetoothIds: Set<CBPeripheralIdentifier>,
                name: String) {
        self.localBluetoothIds = localBluetoothIds
        self.mac = mac
        self.serial = serial
        self.model = model
        self.modules = modules
        self.name = name
    }
}

// MARK: - Utilities

extension MetaWearMetadata: Comparable {
    public static func < (lhs: MetaWearMetadata, rhs: MetaWearMetadata) -> Bool {
        let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        guard nameComparison == .orderedSame else { return nameComparison == .orderedAscending }
        let idComparison = lhs.id.localizedCaseInsensitiveCompare(rhs.id)
        return idComparison == .orderedAscending
    }
}
