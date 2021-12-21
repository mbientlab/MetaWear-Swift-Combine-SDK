// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear

public extension MetaWear {

    /// Basic semi-permanent identifying information for a MetaWear across Apple devices.
    ///
    /// - Warning: Do not depend on `Codable` conformance for persistence.
    ///            Use for in-memory drag and drop only.
    ///
    struct Metadata: Identifiable, Codable {
        /// Identified by MAC address
        public var id: String { mac }
        public var mac: MACAddress
        public var serial: String
        public var model: Model
        public var modules: [MWModules.ID:MWModules]

        public var localBluetoothIds: Set<CBPeripheralIdentifier>
        public var name: String

        public init(mac: String,
                    serial: String,
                    model: Model,
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
}

// MARK: - Utilities

extension MetaWear.Metadata: Comparable {
    public static func < (lhs: MetaWear.Metadata, rhs: MetaWear.Metadata) -> Bool {
        let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        guard nameComparison == .orderedSame else { return nameComparison == .orderedAscending }
        let idComparison = lhs.id.localizedCaseInsensitiveCompare(rhs.id)
        return idComparison == .orderedAscending
    }
}